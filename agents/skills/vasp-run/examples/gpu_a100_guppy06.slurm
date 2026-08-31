#!/bin/bash
#SBATCH --job-name=vasp-a100
#SBATCH --partition=guppy06
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:2
#SBATCH --time=04:00:00
#SBATCH --output=%x-%j.out
#
# A100 run on guppy06 (2x A100-SXM4-80GB, cc80) -- the reference GPU machine.
# ONE RANK PER CARD, always. For a single-GPU run:
#
#   sbatch --ntasks=1 --gres=gpu:1 gpu_a100_guppy06.slurm
#   sbatch --export=ALL,EXE=vasp_gam,WORK=/path/to/case gpu_a100_guppy06.slurm
#   sbatch --exclusive gpu_a100_guppy06.slurm          # for timing runs
#
# REQUIRES a binary built ON guppy06: its glibc is 2.28, older than the login
# nodes, so a binary linked elsewhere dies before printing its banner (no OUTCAR,
# no error). Use gpu_a100_guppy06_injob_build.slurm if you do not have one yet.
# ---------------------------------------------------------------------------
set -uo pipefail

BLD=${BLD:-$HOME/scratch/gpu_test/build_a100_val0829}   # built ON guppy06
EXE=${EXE:-vasp_std}
WORK=${WORK:-$PWD}

module purge 2>/dev/null || true
module unload vasp-intel-dev 2>/dev/null || true        # conflicts with nvhpc, silently
module load vasp-nvhpc_mkl-dev/26.3_mkl-2026.0.0_ompi-5.0.9 || { echo "ABORT: toolchain"; exit 1; }
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
export OMP_STACKSIZE=2048m
unset OMP_PROC_BIND OMP_PLACES        # let slurm bind; these can pin every rank onto one core set

[ -x "$BLD/bin/$EXE" ] || { echo "ABORT: no $BLD/bin/$EXE"; exit 1; }
cd "$WORK" || exit 1

echo "=== $(hostname) $(date) ==="
nvidia-smi --query-gpu=index,name,memory.used --format=csv,noheader
echo "binary : $BLD/bin/$EXE   md5 $(md5sum "$BLD/bin/$EXE" | cut -c1-12)"
echo "layout : ${SLURM_NTASKS} ranks x ${SLURM_CPUS_PER_TASK} cpus/task, gpus ${SLURM_JOB_GPUS:-unset}"

# plain srun: pmix is site-wide since 2026-07-31, so no --mpi=, no --map-by, no -c
srun -n "${SLURM_NTASKS}" --cpu-bind=cores "$BLD/bin/$EXE" > stdout.log 2>&1
rc=$?

echo "=== rc=$rc $(date) ==="
grep -m1 "running .* mpi-ranks" OUTCAR 2>/dev/null || echo "WARNING: no banner -- glibc mismatch?"
grep -m1 "Offloading initialized" OUTCAR 2>/dev/null || echo "WARNING: no GPU line -- CPU fallback?"
grep "LOOP+" OUTCAR 2>/dev/null | tail -1
exit $rc
