#!/bin/bash
# Run VASP on a workstation that is NOT in slurm (wahoo04) or where you simply
# do not want the queue. Pins by hand, because nothing else will.
#
#   ssh wahoo04
#   ~/.claude/skills/vasp-run/examples/workstation_local.sh /path/to/case
#   CORES=8-15 EXE=vasp_gam workstation_local.sh /path/to/case     # second concurrent run
#
# WHY THE PINNING: `mpirun -np 1` with no mapping binds rank 0 to core 0 -- for
# EVERY such job -- so two concurrent single-rank runs timeshare one core at
# ~50 % each while the rest of the box idles. Results stay correct; timings are
# worthless. Rescue an already-running one with `taskset -a -pc 0-7 <pid>`.
# ---------------------------------------------------------------------------
set -uo pipefail

WORK=${1:-$PWD}
BLD=${BLD:-$HOME/git/vasp/gpu-scf/build_rtx6000}     # node-local; exists only on wahoo04
EXE=${EXE:-vasp_std}
CORES=${CORES:-0-7}
THREADS=${THREADS:-$(( $(echo "$CORES" | awk -F- '{print $2-$1+1}') ))}

module load vasp-nvhpc_mkl-dev/26.3_mkl-2026.0.0_ompi-5.0.9 >/dev/null 2>&1
# Blackwell (cc120, wahoo04/wahoo07) also needs the CUDA overlay at run time
module load cuda-overlay/13.1_nvhpc-26.3 >/dev/null 2>&1 || true
command -v mpirun >/dev/null || { echo "ABORT: toolchain did not load"; exit 1; }

# the login environment presets these to 1 -- force them
export OMP_NUM_THREADS=$THREADS MKL_NUM_THREADS=$THREADS OMP_STACKSIZE=2048m

[ -x "$BLD/bin/$EXE" ] || { echo "ABORT: no $BLD/bin/$EXE (build dirs here are node-local)"; exit 1; }
cd "$WORK" || exit 1

# a timing run wants the card to itself
nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu --format=csv,noheader

echo "=== $(hostname) $(date) ; cores $CORES x $THREADS threads ==="
taskset -c "$CORES" mpirun -np 1 --bind-to none "$BLD/bin/$EXE" > stdout.log 2>&1
rc=$?

grep -m1 "running .* mpi-ranks" OUTCAR 2>/dev/null
grep -m1 "Offloading initialized" OUTCAR 2>/dev/null
grep "LOOP+" OUTCAR 2>/dev/null | tail -1
echo "=== rc=$rc $(date) ==="
exit $rc
