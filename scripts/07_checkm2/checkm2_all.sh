#!/bin/bash

#SBATCH --job-name=checkm2_all
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=24:00:00
#SBATCH --output=logs/checkm2_all_%j.out
#SBATCH --error=logs/checkm2_all_%j.err

set -euo pipefail

STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
CHECKM2_DB="${CHECKM2_DB:?Set CHECKM2_DB to uniref100.KO.1.dmnd}"
INPUT="${MAG_DIR:-$STAGE_DIR/input_mags}"
OUT="${CHECKM2_OUT:-$STAGE_DIR/checkm2_all}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate checkm2

# 防止覆盖已有正式结果
if [[ -e "$OUT" ]]; then
    echo "ERROR: output directory already exists: $OUT" >&2
    exit 1
fi

echo "============================================================"
echo "07 CheckM2 - ALL MAGs"
echo "============================================================"
echo "Node       : $SLURMD_NODENAME"
echo "CPUs       : $SLURM_CPUS_PER_TASK"
echo "Memory     : 24G"
echo "Input MAGs : $(find "$INPUT" -maxdepth 1 -type l | wc -l)"
echo "Start      : $(date)"
echo "============================================================"

/usr/bin/time -v \
    -o "$STAGE_DIR/checkm2_all.time.log" \
    checkm2 predict \
        --input "$INPUT" \
        --output-directory "$OUT" \
        --database_path "$CHECKM2_DB" \
        --threads "$SLURM_CPUS_PER_TASK" \
        -x fa \
        > "$STAGE_DIR/checkm2_all.log" 2>&1

test -s "$OUT/quality_report.tsv"

N_RESULT=$(awk 'NR>1 {n++} END{print n+0}' "$OUT/quality_report.tsv")

echo
echo "CheckM2 MAG results = $N_RESULT"

if [[ "$N_RESULT" -ne 2782 ]]; then
    echo "ERROR: expected 2782 MAGs, got $N_RESULT" >&2
    exit 1
fi

touch "$STAGE_DIR/.checkm2.done"

echo
echo "============================================================"
echo "CheckM2 FINISHED"
echo "Results : $OUT/quality_report.tsv"
echo "MAGs    : $N_RESULT"
echo "Finish  : $(date)"
echo "============================================================"
