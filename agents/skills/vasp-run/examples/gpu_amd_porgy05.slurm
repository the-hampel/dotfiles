#!/bin/bash
#SBATCH --job-name=vasp-mi210
#SBATCH --partition=porgy05
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=6
#SBATCH --gres=gpu:4
#SBATCH --time=04:00:00
#SBATCH --output=%x-%j.out
#
# AMD MI210 (gfx90a) run on porgy05, OpenMP target offload, Cray CCE 19.
#
# THIS IS THE ONE MACHINE WHERE srun IS NOT USED. Compiler, MPI and launcher all
# live in the ccpe container, so the batch step calls the CI container helper
# directly and the launcher INSIDE is cray-pals mpiexec plus the CI rank wrapper.
#
#   sbatch --export=ALL,VASP_DIR=$HOME/git/vasp/gpu-scf-cray,WORK=/path gpu_amd_porgy05.slurm
#   sbatch --gres=none --export=ALL,USE_GPU=0,VASP_DIR=<cpu tree> gpu_amd_porgy05.slurm
#
# --pals gives a JOB-LOCAL palsd (own port, own keypair, killed on EXIT), so the
# ranks stay inside the slurm cgroup and /opt/scripts/vasp-rank-wrapper.sh pins
# them across CCPE_CPU_LIST / CCPE_GPU_LIST -- what slurm actually allocated.
# No --exclusive needed and safe to share the node; it neither touches nor needs
# palsd@<user>.service.
#
# For the testsuite or the CheFSI-vs-Normal validation use the maintained
# scripts instead: ~/git/vasp/porgy05_cray_conf/{test_cray,val_cray}.slurm
# (its README.md documents the whole set).
# ---------------------------------------------------------------------------
set -uo pipefail

VASP_DIR=${VASP_DIR:-$HOME/git/vasp/gpu-scf-cray}
EXE=${EXE:-vasp_std}
WORK=${WORK:-$PWD}
NRANKS=${NRANKS:-${SLURM_NTASKS:-4}}
CEXEC=/opt/share/singularity/ccpe/bin/container-exec.sh

# container-exec.sh forwards every ^VASP_* var, and apptainer's --env rejects a
# value with a comma after a second '=' -- exactly the shape of the vasp-dev
# toolchain's VASP_FC_GPU_TARGETS / VASP_LLIBS_EXTRAS. Submitting from a shell
# with that module loaded dies in ~3 s on an apptainer usage dump. Keep only the
# vars the ranks actually need.
for v in $(env | sed -n 's/^\(VASP_[A-Z_0-9]*\)=.*/\1/p'); do
    case "$v" in VASP_TESTSUITE_*|VASP_GPU_*|VASP_DIR) : ;; *) unset "$v" ;; esac
done
unset SLURMCTLD_OPTIONS SLURMRESTD_OPTIONS

# threads come from the slurm TaskProlog hook (--cpus-per-task, only if unset);
# the container is a separate environment, so pass through whatever the batch
# step ended up with rather than deciding here
THREADS=${OMP_NUM_THREADS:-${SLURM_CPUS_PER_TASK:-6}}
rm -f "$WORK/acc.debug"          # CRAY_ACC_DEBUG_FILE is opened in APPEND mode

# the command the ranks run, written where the container can see it
RUNNER=$WORK/.run_in_container.sh
cat > "$RUNNER" <<INNER
#!/bin/bash
set -u
cd "$WORK" || exit 1
export OMP_NUM_THREADS=${THREADS}
echo "launcher: mpiexec -np ${NRANKS} -ppn ${NRANKS} --hosts localhost + rank wrapper"
mpiexec -np ${NRANKS} -ppn ${NRANKS} --hosts localhost \
        /opt/scripts/vasp-rank-wrapper.sh "${VASP_DIR}/bin/${EXE}" > stdout.log 2>&1 < /dev/null
INNER
chmod +x "$RUNNER"

GPU_ARGS=(); [ "${USE_GPU:-1}" = 1 ] && GPU_ARGS=(--gpu)

echo "=== $(hostname) $(date) ==="
echo "tree   : $VASP_DIR   exe: $EXE   ranks: $NRANKS x ${THREADS} threads"
echo "cpus   : $(awk '/Cpus_allowed_list/{print $2}' /proc/self/status)   gpus: ${SLURM_JOB_GPUS:-unset}"

"$CEXEC" "${GPU_ARGS[@]}" --pals "$RUNNER"
rc=$?

case $rc in
  42) echo "=== ABORTED: mpiexec could not reach the job-local palsd ===";;
  44) echo "=== ABORTED: ranks cannot see $VASP_DIR -- a palsd bind is missing ===";;
esac
cd "$WORK" 2>/dev/null && { grep -m1 "running .* mpi-ranks" OUTCAR 2>/dev/null; grep "LOOP+" OUTCAR 2>/dev/null | tail -1; }
echo "=== rc=$rc $(date) ==="
exit $rc
