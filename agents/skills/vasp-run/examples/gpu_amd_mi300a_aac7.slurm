#!/bin/bash -l
# ---------------------------------------------------------------------------
# VASP on AMD MI300A — AAC7 (AMD Accelerator Cloud), Cray CCE + ROCm.
#
#   ssh aac                                     # this is a REMOTE site, not deep blue
#   sbatch -p 192C4G1H_MI300A_RHEL9_A1 -N 1 --time=02:00:00 \
#          --export=ALL,RANKS=4,NODES=1,WORKDIR=$HOME/benchmark/mycase \
#          gpu_amd_mi300a_aac7.slurm
#
# `#!/bin/bash -l` is REQUIRED: `module` is only defined in a login shell there.
#
# One rank per MI300A die, 4 dies per node. Single node is the only configuration
# that is fast AND stable here -- see the multi-node note at the bottom.
# ---------------------------------------------------------------------------
#SBATCH --job-name=vasp_mi300a
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=24
#SBATCH --gres=gpu:4

S=${S:-$HOME/git/vasp/cce21_scripts}          # env_cce21.sh + bind_gpu_mn.sh live here
BIN=${BIN:-$HOME/git/vasp/gpu-scf/bin/vasp_std}
WORKDIR=${WORKDIR:?WORKDIR must be set (dir holding INCAR/POSCAR/POTCAR/KPOINTS)}
RANKS=${RANKS:-4}
NODES=${NODES:-1}

source "$S/env_cce21.sh"                      # PrgEnv-cray + rocm-new + the -lamdhip64 fix
command -v ftn >/dev/null || { echo "ABORT: CCE toolchain did not load"; exit 1; }

# --- MPI / GPU transport ---------------------------------------------------
export MPICH_OFI_NIC_POLICY=GPU MPICH_OFI_RMA_STARTUP_CONNECT=1 MPICH_OFI_STARTUP_CONNECT=1
export MPICH_ALLTOALL_SHORT_MSG=4096 MPICH_ALLTOALL_SYNC_FREQ=24
export MPICH_GPU_SUPPORT_ENABLED=1 MPICH_GPU_IPC_THRESHOLD=8192
unset NCCL_LAUNCH_ORDER_IMPLICIT              # =1 makes multi-rank RCCL segfault here
export HSA_XNACK=0 HSA_NO_SCRATCH_RECLAIM=0
export GTL_DISABLE_HSA_IPC_SIGNAL_CACHE=0 GPU_MAX_HW_QUEUES=8
export AMD_SERIALIZE_KERNEL=0 AMD_SERIALIZE_COPY=0

# --- rocFFT runtime-compilation cache --------------------------------------
# Per-run private cache; the shared system cache is disabled so runs cannot
# contend on it. rocFFT plan construction is seconds-scale on this card.
export ROCFFT_RTC_PROCESS=2 ROCFFT_RTC_SYS_CACHE_PATH=/dev/null
export ROCFFT_RTC_CACHE_PATH="$WORKDIR/rocfft_cache"

# --- OpenMP ----------------------------------------------------------------
# No TaskProlog hook on this site: set the thread count BY HAND.
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=2048m OMP_PLACES=cores OMP_PROC_BIND=close OMP_WAIT_POLICY=PASSIVE
export OMP_TARGET_OFFLOAD=DEFAULT
ulimit -s unlimited

cd "$WORKDIR" || exit 1

# Cray Fortran unbuffered I/O: without this OUTCAR/OSZICAR lag far behind the run.
export FILENV="$WORKDIR/vasp.io_settings"
assign -y on g:all

# CRAY_ACC_DEBUG_FILE appends -- drop a stale one or you read the previous run.
rm -f acc.debug

echo "### $(basename "$BIN")  ${RANKS} ranks / ${NODES} node(s)  on $SLURM_JOB_NODELIST ###"

srun -N "$NODES" -n "$RANKS" --ntasks-per-node=4 --gpus-per-node=4 \
     "$S/bind_gpu_mn.sh" "$BIN" > stdout.txt 2>&1
rc=$?

# --- did it actually run? --------------------------------------------------
echo "rc=$rc"
grep -m1 "running .* mpi-ranks"    stdout.txt || echo "!! no rank banner -- died before startup"
grep -m1 "Offloading initialized"  stdout.txt || echo "!! no offload banner"
grep    "LOOP+"  OUTCAR 2>/dev/null | tail -1
grep -c "aborting loop because EDIFF is reached" OUTCAR 2>/dev/null
grep -oE "Memory access fault|Segmentation fault|SICK JOB|hsa_amd_ipc_memory_attach" stdout.txt \
     2>/dev/null | sort -u

# ---------------------------------------------------------------------------
# MULTI-NODE (NODES>1) is degraded on this machine, not by VASP:
#   * RCCL has no OFI/Slingshot plugin (no librccl-net-ofi.so in ROCm 7.2.1), so
#     inter-node collectives fall back to sockets -- add LUSENCCL=.FALSE. to the
#     INCAR or it is ~7x slower;
#   * cray-mpich GPU IPC can fail with hsa_amd_ipc_memory_attach:
#     HSA_STATUS_ERROR_INVALID_ARGUMENT -- raise MPICH_GPU_IPC_THRESHOLD above the
#     largest message (e.g. 2e9);
#   * even with both, 8 ranks over 2 nodes has died with a GPU memory access fault.
# Treat >1 node as a CORRECTNESS check only. Energies reproduce; timings do not.
# ---------------------------------------------------------------------------
