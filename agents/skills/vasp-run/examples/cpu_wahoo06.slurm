#!/bin/bash
#SBATCH --job-name=vasp-cpu
#SBATCH --partition=wahoo06
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=8
#SBATCH --time=04:00:00
#SBATCH --output=%x-%j.out
#
# CPU run on wahoo06 (32 cores) -- the default for CPU work on this cluster.
# 4 ranks x 8 threads fills the node and matches the rank count the testsuite
# references were generated with.
#
#   sbatch cpu_wahoo06.slurm
#   sbatch --export=ALL,BLD=$HOME/git/vasp/gpu-scf/build_intel,EXE=vasp_gam cpu_wahoo06.slurm
#   sbatch --export=ALL,WORK=/path/to/case cpu_wahoo06.slurm
#
# Bigger CPU runs: same script with -p porgy02 (128 cores) and --ntasks=16.
# ---------------------------------------------------------------------------
set -uo pipefail

BLD=${BLD:-$HOME/git/vasp/gpu-scf/build_intel}     # build dir containing bin/
EXE=${EXE:-vasp_std}
WORK=${WORK:-$PWD}
TOOLCHAIN=${TOOLCHAIN:-vasp-intel-dev}             # must match how BLD was built

module purge 2>/dev/null || true                   # NOT --export=NONE: it breaks the srun step
module load $(module avail 2>&1 | tr ' ' '\n' | grep "^${TOOLCHAIN}/" | sort -V | tail -1) \
  || { echo "ABORT: could not load ${TOOLCHAIN}"; exit 1; }
command -v mpirun >/dev/null || { echo "ABORT: toolchain did not load (assert on the tool, not on \$?)"; exit 1; }

# threads: do NOT set them. The slurm TaskProlog hook fills OMP_NUM_THREADS and
# MKL_NUM_THREADS from --cpus-per-task, but ONLY if they are unset -- and a login
# shell here exports MKL_NUM_THREADS=1, which sbatch propagates and the hook then
# honours (measured: task gets OMP=8 MKL=1, so every MKL rank runs single-threaded).
# Unsetting them in the batch step hands the decision back to the hook (measured:
# OMP=8 MKL=8 with --cpus-per-task=8).
unset OMP_NUM_THREADS MKL_NUM_THREADS
export OMP_STACKSIZE=2048m
export OMP_PLACES=cores OMP_PROC_BIND=close OMP_WAIT_POLICY=PASSIVE

[ -x "$BLD/bin/$EXE" ] || { echo "ABORT: no $BLD/bin/$EXE"; exit 1; }
cd "$WORK" || exit 1
for f in INCAR POSCAR POTCAR KPOINTS; do [ -e $f ] || echo "note: no $f in $WORK"; done

echo "=== $(hostname) $(date) ==="
echo "binary : $BLD/bin/$EXE"
echo "layout : ${SLURM_NTASKS} ranks x ${SLURM_CPUS_PER_TASK} cpus/task (threads set by the hook)"
echo "cpus   : $(awk '/Cpus_allowed_list/{print $2}' /proc/self/status)"

srun -n "${SLURM_NTASKS}" --cpu-bind=cores "$BLD/bin/$EXE" > stdout.log 2>&1
rc=$?

echo "=== rc=$rc $(date) ==="
grep -m1 "running .* mpi-ranks" OUTCAR 2>/dev/null || echo "WARNING: no rank banner -- did it start?"
grep "LOOP+" OUTCAR 2>/dev/null | tail -1
tail -3 OUTCAR 2>/dev/null
exit $rc
