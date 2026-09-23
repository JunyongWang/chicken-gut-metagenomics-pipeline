#!/bin/bash
#SBATCH --job-name=dbcan_MAG
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=06:00:00
#SBATCH --output=logs/dbcan_MAG_%A_%a.out
#SBATCH --error=logs/dbcan_MAG_%A_%a.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/12_function}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
DBCAN_ENV="${DBCAN_ENV:-dbcan}"
DBCAN_DB="${DBCAN_DB:?Set DBCAN_DB to the dbCAN 5.2.9 database directory}"
DBCAN_MAG_CHUNKS_FILE="${DBCAN_MAG_CHUNKS_FILE:-$STAGE_DIR/dbcan/11B/chunks.txt}"

cd "$STAGE_DIR"
source "$CONDA_SH"
conda activate "$DBCAN_ENV"

DB="$DBCAN_DB"

CHUNK=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$DBCAN_MAG_CHUNKS_FILE")

BASE="${CHUNK%.faa}"
IN="$STAGE_DIR/dbcan/11B/chunks/$CHUNK"
OUT="$STAGE_DIR/dbcan/11B/results/$BASE"

OVERVIEW="$OUT/overview.tsv"
DONE="$OUT/.dbcan.done"

[[ -s "$IN" ]]
[[ -s "$DB/CAZy.dmnd" ]]
[[ -s "$DB/dbCAN.hmm" ]]
[[ -s "$DB/dbCAN-sub.hmm" ]]
[[ -s "$DB/fam-substrate-mapping.tsv" ]]
[[ -e "$DB/.download_complete" ]]

rm -rf "$OUT"
mkdir -p "$OUT"

/usr/bin/time -v \
  -o "$OUT/time.log" \
  run_dbcan CAZyme_annotation \
    --input_raw_data "$IN" \
    --output_dir "$OUT" \
    --db_dir "$DB" \
    --mode protein \
    --methods diamond,hmm,dbCANsub \
    --threads "$SLURM_CPUS_PER_TASK"

[[ -s "$OVERVIEW" ]]
[[ -s "$OUT/dbCAN_hmm_results.tsv" ]]
[[ -s "$OUT/dbCANsub_hmm_results.tsv" ]]
[[ -s "$OUT/diamond.out" ]]

INPUT_N=$(grep -c '^>' "$IN")

OVERVIEW_N=$(
    awk -F'\t' '
    NR>1 && NF>0 {
        n++
    }
    END {
        print n+0
    }
    ' "$OVERVIEW"
)

RECOMMENDED_N=$(
    awk -F'\t' '
    NR>1 && $6+0 >= 2 {
        n++
    }
    END {
        print n+0
    }
    ' "$OVERVIEW"
)

{
    printf 'chunk\tinput_proteins\toverview_genes\trecommended_genes\n'
    printf '%s\t%s\t%s\t%s\n' \
      "$BASE" \
      "$INPUT_N" \
      "$OVERVIEW_N" \
      "$RECOMMENDED_N"
} > "$OUT/qc.tsv"

touch "$DONE"
