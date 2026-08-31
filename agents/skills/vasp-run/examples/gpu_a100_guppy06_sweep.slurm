#!/bin/bash
#SBATCH --job-name=vasp-a100-sweep
#SBATCH --partition=guppy06
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:2
#SBATCH --exclusive
#SBATCH --time=08:00:00
#SBATCH --output=%x-%j.out
#
# Benchmark sweep on A100: several settings, INTERLEAVED and repeated.
#
#   sbatch --export=ALL,WORK=/path/to/case,KEY=CHEFSI_NDEG,VALUES="3 4 5 6",REPS=2 \
#          gpu_a100_guppy06_sweep.slurm
#
# WHY INTERLEAVED: running all of arm A and then all of arm B lets any drift in
# node load land entirely inside the comparison. On a shared node that has
# INVERTED a result (2.2 % slower vs 13.8 % faster, same binaries, same node).
# The tell is both arms coming out bimodal rather than scattered. So the loop is
#     for rep: for value: run
# not for value: for rep: run, and the repeats bracket the whole sweep.
#
# --exclusive because these are timings. Drop it for correctness runs.
# ---------------------------------------------------------------------------
set -uo pipefail

BLD=${BLD:-$HOME/scratch/gpu_test/build_a100_val0829}
EXE=${EXE:-vasp_std}
WORK=${WORK:-$PWD}                 # must hold INCAR.base POSCAR KPOINTS POTCAR
KEY=${KEY:-CHEFSI_NDEG}
VALUES=${VALUES:-"3 4 5 6"}
REPS=${REPS:-2}
OUT=${OUT:-$WORK/sweep-$SLURM_JOB_ID}

module purge 2>/dev/null || true
module unload vasp-intel-dev 2>/dev/null || true
module load vasp-nvhpc_mkl-dev/26.3_mkl-2026.0.0_ompi-5.0.9 || { echo "ABORT: toolchain"; exit 1; }
# threads: do NOT set them. The slurm TaskProlog hook fills OMP_NUM_THREADS and
# MKL_NUM_THREADS from --cpus-per-task, but ONLY if they are unset -- and a login
# shell here exports MKL_NUM_THREADS=1, which sbatch propagates and the hook then
# honours (measured: task gets OMP=8 MKL=1, so every MKL rank runs single-threaded).
# Unsetting them in the batch step hands the decision back to the hook (measured:
# OMP=8 MKL=8 with --cpus-per-task=8).
unset OMP_NUM_THREADS MKL_NUM_THREADS
export OMP_STACKSIZE=2048m
unset OMP_PROC_BIND OMP_PLACES
mkdir -p "$OUT"; : > "$OUT/results.tsv"

run_one () {                       # $1 value  $2 rep
    local val=$1 rep=$2 d="$OUT/${KEY}_${val}_r${rep}"
    rm -rf "$d"; mkdir -p "$d"
    cp "$WORK"/{POSCAR,KPOINTS,POTCAR} "$d"/ 2>/dev/null
    cp "$WORK/INCAR.base" "$d/INCAR"
    # VASP honours the FIRST occurrence of a key, and a key can hide after a ';'
    # -- so REPLACE everywhere, never append, then assert the resolved value below
    sed -i -E "s/(^|;)[[:space:]]*${KEY}[[:space:]]*=[[:space:]]*[^;]*/\1/Ig" "$d/INCAR"
    printf '%s = %s\n' "$KEY" "$val" >> "$d/INCAR"
    ( cd "$d" && srun -n "${SLURM_NTASKS}" --cpu-bind=cores "$BLD/bin/$EXE" > stdout.log 2>&1 )
    local loop steps f
    loop=$(grep "LOOP+" "$d/OUTCAR" | tail -1 | awk '{print $NF}')
    steps=$(grep -cE "^(DAV|RMM|GPU):" "$d/OSZICAR" 2>/dev/null)
    f=$(awk '/F=/{v=$5} END{print v}' "$d/OSZICAR" 2>/dev/null)
    printf '%-18s %-4s %-6s %-10s %s\n' "$KEY=$val" "r$rep" "$steps" "${loop:-FAILED}" "$f" \
        | tee -a "$OUT/results.tsv"
}

echo "=== $(hostname) $(date) ; sweep $KEY over [$VALUES] x $REPS reps, interleaved ==="
for rep in $(seq 1 "$REPS"); do
    for val in $VALUES; do run_one "$val" "$rep"; done
done

echo; echo "=== results ($OUT/results.tsv) ==="; cat "$OUT/results.tsv"
echo "Compare PAIRED across reps; report how many pairs agree on the sign."
