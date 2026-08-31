#!/bin/bash
#SBATCH --job-name=vasp-intelgpu-test
#SBATCH --partition=guppy07
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=32
#SBATCH --gres=gpu:2
#SBATCH --time=06:00:00
#SBATCH --output=%x-%j.out
#
# Regression testsuite on the Intel Max 1100 build. Same launch rules as
# gpu_intel_guppy07.slurm; the difference is that runtest wants the launch line
# in VASP_TESTSUITE_EXE_{STD,NCL,GAM}.
#
#   sbatch --export=ALL,BLD=/path/to/build_intel_off,TESTS="CrS_CheFSI" gpu_intel_guppy07_testsuite.slurm
#   sbatch --export=ALL,TESTS="" ...            # whole FAST suite
#
# ~/git/vasp/intel_gpu.conf is the maintained copy of this environment.
# ---------------------------------------------------------------------------
set -uo pipefail

BLD=${BLD:-$HOME/git/vasp/master-cmake/build_intel_off}
SRC=${SRC:-$HOME/git/vasp/master-cmake}
WRAP=${WRAP:-$HOME/git/vasp/srun_ze.sh}
TESTS=${TESTS:-CrS_CheFSI}

module purge 2>/dev/null || true
module load $(module avail 2>&1 | tr ' ' '\n' | grep '^vasp-intel-dev/' | sort -V | tail -1) \
  || { echo "ABORT: toolchain"; exit 1; }
module unload libxc 2>/dev/null || true

# threads: do NOT set them. The slurm TaskProlog hook fills OMP_NUM_THREADS and
# MKL_NUM_THREADS from --cpus-per-task, but ONLY if they are unset -- a value the
# submitter set always wins. The unset here is belt-and-braces: the login profile
# stopped exporting them on 2026-08-31, but any process started BEFORE that (a
# tmux window, an ssh session, a long-running agent) still carries the old values
# and sbatch propagates whatever the submitting shell has. Measured on wahoo06 at
# --cpus-per-task=8: with MKL_NUM_THREADS=1 inherited the task gets OMP=8 MKL=1
# (MKL single-threaded while OpenMP is not); unset, it gets OMP=8 MKL=8.
unset OMP_NUM_THREADS MKL_NUM_THREADS
export I_MPI_OFFLOAD=1 OMP_TARGET_OFFLOAD=DEFAULT OMP_STACKSIZE=2048m I_MPI_PIN_DOMAIN=omp
export NEO_CACHE_DIR=$HOME/.intel_caches/neo_cache   NEO_CACHE_PERSISTENT=1
export SYCL_CACHE_DIR=$HOME/.intel_caches/sycl_cache SYCL_CACHE_PERSISTENT=1
mkdir -p "$NEO_CACHE_DIR" "$SYCL_CACHE_DIR"

export VASP_PATH=$BLD
export VASP_TESTSUITE_TESTS="$TESTS"
export VASP_TESTSUITE_EXE_STD="srun -n ${SLURM_NTASKS} $WRAP $BLD/bin/vasp_std"
export VASP_TESTSUITE_EXE_NCL="srun -n ${SLURM_NTASKS} $WRAP $BLD/bin/vasp_ncl"
export VASP_TESTSUITE_EXE_GAM="srun -n ${SLURM_NTASKS} $WRAP $BLD/bin/vasp_gam"

# the comparator is rebuilt only if MISSING, so a stale one from another glibc
# silently "passes" every check -- delete it and let runtest rebuild it here
rm -f "$SRC/testsuite/tools/compare_numbertable_new"

cd "$SRC/testsuite" || exit 1
echo "=== $(hostname) $(date) ; tests: ${TESTS:-<category>} ==="
./runtest 2>&1 | tee "testsuite-$SLURM_JOB_ID.log"

echo "=== verdict ==="
grep -c "ERROR:" "testsuite-$SLURM_JOB_ID.log"
grep -E "GLIBC|SUCCESS|tests failed" "testsuite-$SLURM_JOB_ID.log" | tail -5
