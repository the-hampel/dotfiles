#!/bin/bash
#SBATCH --job-name=vasp-intelgpu
#SBATCH --partition=guppy07
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=32
#SBATCH --gres=gpu:2
#SBATCH --time=04:00:00
#SBATCH --output=%x-%j.out
#
# Intel Data Center GPU Max 1100 (PVC) run on guppy07, OpenMP target offload.
# ONE RANK PER CARD. Single card: --ntasks=1 --gres=gpu:1.
#
#   sbatch --export=ALL,BLD=$HOME/git/vasp/master-cmake/build_intel_off,WORK=/path gpu_intel_guppy07.slurm
#
# THREE things are specific to this node:
#  1. it auto-suspends (sinfo shows idle~). The first job WAKES it, which costs
#     ~2 min before anything starts. That is normal, not a hung job.
#  2. NO --exclusive here (site convention); --cpus-per-task=32 of its 112 cores.
#  3. the launcher is srun PLUS the one-line wrapper ~/git/vasp/srun_ze.sh:
#     Intel MPI <= 2021.17 runs its topology detection in the launcher, which
#     fails under srun, and with I_MPI_OFFLOAD=1 the library then walks the
#     uninitialised topology and SIGSEGVs before any user code runs. Defining
#     I_MPI_PIN_MAPPING (all the wrapper does) skips that path; slurm still does
#     the binding. oneAPI 2026 / Intel MPI 2021.18 guards against it.
# ---------------------------------------------------------------------------
set -uo pipefail

BLD=${BLD:-$HOME/git/vasp/master-cmake/build_intel_off}
EXE=${EXE:-vasp_std}
WORK=${WORK:-$PWD}
WRAP=${WRAP:-$HOME/git/vasp/srun_ze.sh}

module purge 2>/dev/null || true
module load $(module avail 2>&1 | tr ' ' '\n' | grep '^vasp-intel-dev/' | sort -V | tail -1) \
  || { echo "ABORT: could not load vasp-intel-dev"; exit 1; }
module unload libxc 2>/dev/null || true      # CI does this; LibXC is off for the offload build
command -v mpirun >/dev/null || { echo "ABORT: toolchain did not load"; exit 1; }

# threads: do NOT set them. The slurm TaskProlog hook fills OMP_NUM_THREADS and
# MKL_NUM_THREADS from --cpus-per-task, but ONLY if they are unset -- a value the
# submitter set always wins. The unset here is belt-and-braces: the login profile
# stopped exporting them on 2026-08-31, but any process started BEFORE that (a
# tmux window, an ssh session, a long-running agent) still carries the old values
# and sbatch propagates whatever the submitting shell has. Measured on wahoo06 at
# --cpus-per-task=8: with MKL_NUM_THREADS=1 inherited the task gets OMP=8 MKL=1
# (MKL single-threaded while OpenMP is not); unset, it gets OMP=8 MKL=8.
unset OMP_NUM_THREADS MKL_NUM_THREADS
export I_MPI_OFFLOAD=1
export OMP_TARGET_OFFLOAD=DEFAULT
export OMP_STACKSIZE=2048m
export I_MPI_PIN_DOMAIN=omp
# persistent JIT caches -- without them every run re-compiles the device code
export NEO_CACHE_DIR=$HOME/.intel_caches/neo_cache   NEO_CACHE_PERSISTENT=1
export SYCL_CACHE_DIR=$HOME/.intel_caches/sycl_cache SYCL_CACHE_PERSISTENT=1
mkdir -p "$NEO_CACHE_DIR" "$SYCL_CACHE_DIR"
# per-rank GPU binding is NOT needed: INIT_OFFLOAD (src/openmp.F) round-robins
# DEVICE_NUM = MOD(rank, OMP_GET_NUM_DEVICES()) itself

[ -x "$BLD/bin/$EXE" ] || { echo "ABORT: no $BLD/bin/$EXE"; exit 1; }
[ -x "$WRAP" ] || { echo "ABORT: no wrapper at $WRAP"; exit 1; }
cd "$WORK" || exit 1

echo "=== $(hostname) $(date) ==="
xpu-smi discovery 2>/dev/null | head -12 || true
echo "layout : ${SLURM_NTASKS} ranks x ${SLURM_CPUS_PER_TASK} cpus/task, gpus ${SLURM_JOB_GPUS:-unset}"

srun -n "${SLURM_NTASKS}" "$WRAP" "$BLD/bin/$EXE" > stdout.log 2>&1
rc=$?

echo "=== rc=$rc $(date) ==="
grep -m1 "running .* mpi-ranks" OUTCAR 2>/dev/null || echo "WARNING: no banner"
grep -m1 -i "offload" OUTCAR 2>/dev/null
grep "LOOP+" OUTCAR 2>/dev/null | tail -1
exit $rc
