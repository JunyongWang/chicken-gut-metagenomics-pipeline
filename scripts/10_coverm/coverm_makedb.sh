#!/bin/bash

#SBATCH --job-name=coverm_db
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=logs/coverm_db_%j.out
#SBATCH --error=logs/coverm_db_%j.err

set -euo pipefail

STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
INPUT="${MAG_DIR:-$STAGE_DIR/input_mags}"
OUT="${COVERM_DB_DIR:-$STAGE_DIR/db/minimap2_sr}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate metagenomics

N_MAG=$(find -L "$INPUT" -maxdepth 1 -type f -name '*.fa' | wc -l)

echo "============================================================"
echo "CoverM minimap2-sr database"
echo "============================================================"
echo "Node       : $SLURMD_NODENAME"
echo "CPUs       : $SLURM_CPUS_PER_TASK"
echo "MAGs       : $N_MAG"
echo "CoverM     : $(coverm --version)"
echo "Minimap2   : $(minimap2 --version)"
echo "Start      : $(date)"
echo "============================================================"

if [[ "$N_MAG" -ne 374 ]]; then
    echo "ERROR: expected 374 MAGs, got $N_MAG" >&2
    exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"

/usr/bin/time -v \
    -o "$STAGE_DIR/db/coverm_makedb.time.log" \
    coverm makedb \
        -d "$INPUT" \
        -x fa \
        -p minimap2-sr \
        -t "$SLURM_CPUS_PER_TASK" \
        -o "$OUT" \
        > "$STAGE_DIR/db/coverm_makedb.log" 2>&1

touch "$STAGE_DIR/db/.makedb.done"

echo
echo "============================================================"
echo "CoverM database FINISHED"
echo "Finish : $(date)"
echo "============================================================"
