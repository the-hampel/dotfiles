#!/bin/bash
#SBATCH --job-name=vasp-a100-build-run
#SBATCH --partition=guppy06
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:2
#SBATCH --time=06:00:00
#SBATCH --output=%x-%j.out
#
# Build a source tree ON guppy06 and run it in the same job. This is the
# REQUIRED shape for any tree not previously built there: guppy06's glibc is
# 2.28, older than the login nodes, so a binary linked on wahoo starts and dies
# before VASP prints its banner -- no OUTCAR, no error message, just OMPI noise.
#
#   sbatch --export=ALL,REF=HEAD,SRC=$HOME/git/vasp/gpu-scf,WORK=/path/to/case \
#          gpu_a100_guppy06_injob_build.slurm
#
# The build is cached: a second job with the same REF sha reuses it (.ref_<sha>).
# ---------------------------------------------------------------------------
set -uo pipefail

SRC=${SRC:-$HOME/git/vasp/gpu-scf}                    # source tree to snapshot
REF=${REF:-HEAD}
WORK=${WORK:-$PWD}
EXE=${EXE:-vasp_std}
BASE=${BASE:-$HOME/scratch/gpu_test}
SNAP=$BASE/a100snap-$(basename "$SRC")
BLD=$BASE/build_a100-$(basename "$SRC")

module purge 2>/dev/null || true
module unload vasp-intel-dev 2>/dev/null || true
module load vasp-nvhpc_mkl-dev/26.3_mkl-2026.0.0_ompi-5.0.9 || { echo "ABORT: toolchain"; exit 1; }
command -v cmake >/dev/null || { echo "ABORT: no cmake after module load"; exit 1; }

SHA=$(git -C "$SRC" rev-parse --short "$REF") || exit 1
echo "=== $(hostname) $(date) ; $SRC @ $SHA ==="

# nproc reports 1 inside a batch step even with --exclusive -- size -j from the affinity list
NJ=$(awk '/Cpus_allowed_list/{n=split($2,a,","); s=0; for(i=1;i<=n;i++){split(a[i],b,"-"); s+= (b[2]?b[2]-b[1]+1:1)} print s}' /proc/self/status)
NJ=${NJ:-8}

if [ ! -e "$BLD/.ref_$SHA" ]; then
    rm -rf "$SNAP"; mkdir -p "$SNAP"
    git -C "$SRC" archive "$REF" | tar -x -C "$SNAP"
    git -C "$SRC/cmake" archive HEAD | tar -x -C "$SNAP/cmake"
    # git archive DROPS the gitignored CMakeLists.txt symlinks; setup.sh recreates them
    bash "$SNAP/cmake/setup.sh" "$SNAP" > "$SNAP/.setup.log" 2>&1 || { echo "ABORT: cmake/setup.sh"; exit 1; }

    rm -rf "$BLD"
    cmake -S "$SNAP" -B "$BLD" -UVASP_SOURCES_DEFAULT -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CUDA_ARCHITECTURES=80 -DVASP_OPENMP=ON -DVASP_PROFILING=ON \
          -DVASP_HDF5=ON -DVASP_FOCK_DBLBUF=ON -DVASP_CUSOLVERMP=OFF \
          -DVASP_SCALAPACK=ON -DVASP_USE_NCCL=ON > "$BLD.conf.log" 2>&1 \
      || { echo "ABORT: configure, see $BLD.conf.log"; exit 1; }
    for t in $EXE; do
        echo "--- building $t with -j$NJ ($(date +%H:%M))"
        cmake --build "$BLD" --target "$t" -j"$NJ" > "$BLD.build_$t.log" 2>&1 \
          || { echo "ABORT: build $t, see $BLD.build_$t.log"; tail -20 "$BLD.build_$t.log"; exit 1; }
    done
    touch "$BLD/.ref_$SHA"
else
    echo "--- reusing existing build for $SHA"
fi

# threads: do NOT set them. The slurm TaskProlog hook fills OMP_NUM_THREADS and
# MKL_NUM_THREADS from --cpus-per-task, but ONLY if they are unset -- and a login
# shell here exports MKL_NUM_THREADS=1, which sbatch propagates and the hook then
# honours (measured: task gets OMP=8 MKL=1, so every MKL rank runs single-threaded).
# Unsetting them in the batch step hands the decision back to the hook (measured:
# OMP=8 MKL=8 with --cpus-per-task=8).
unset OMP_NUM_THREADS MKL_NUM_THREADS
export OMP_STACKSIZE=2048m
unset OMP_PROC_BIND OMP_PLACES

cd "$WORK" || exit 1
echo "=== run $(date) ; ${SLURM_NTASKS} ranks x ${SLURM_CPUS_PER_TASK} cpus/task ==="
srun -n "${SLURM_NTASKS}" --cpu-bind=cores "$BLD/bin/$EXE" > stdout.log 2>&1
rc=$?
grep -m1 "running .* mpi-ranks" OUTCAR 2>/dev/null
grep -m1 "Offloading initialized" OUTCAR 2>/dev/null
grep "LOOP+" OUTCAR 2>/dev/null | tail -1
echo "=== rc=$rc $(date) ==="
exit $rc
