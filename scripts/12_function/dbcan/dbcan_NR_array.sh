#!/bin/bash
#SBATCH --job-name=dbcan_NR
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=06:00:00
#SBATCH --array=1-132%20
#SBATCH --output=logs/dbcan_NR_%A_%a.out
#SBATCH --error=logs/dbcan_NR_%A_%a.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/12_function}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
DBCAN_ENV="${DBCAN_ENV:-dbcan}"
DBCAN_DB="${DBCAN_DB:?Set DBCAN_DB to the dbCAN 5.2.9 database directory}"

cd "$STAGE_DIR"
source "$CONDA_SH"
conda activate "$DBCAN_ENV"

CHUNK=$(printf '%03d' "$SLURM_ARRAY_TASK_ID")

IN="$STAGE_DIR/eggnog/11A/chunks/chunk_${CHUNK}.faa"
DB="$DBCAN_DB"

BASE="$STAGE_DIR/dbcan/11A/results"
OUT="$BASE/chunk_${CHUNK}"
TMP="$BASE/.chunk_${CHUNK}.tmp.${SLURM_JOB_ID}"

# ------------------------------------------------------------
# Skip an already completed formal chunk
# ------------------------------------------------------------

if [[ -f "$OUT/.dbcan.done" ]]; then
    echo "chunk_${CHUNK} already complete"
    exit 0
fi

# ------------------------------------------------------------
# Input / database checks
# ------------------------------------------------------------

[[ -s "$IN" ]]

[[ -s "$DB/CAZy.dmnd" ]]
[[ -s "$DB/dbCAN.hmm" ]]
[[ -s "$DB/dbCAN-sub.hmm" ]]
[[ -s "$DB/fam-substrate-mapping.tsv" ]]
[[ -e "$DB/.download_complete" ]]

INPUT_N=$(grep -c '^>' "$IN")

if [[ "$SLURM_ARRAY_TASK_ID" -lt 132 ]]; then
    [[ "$INPUT_N" -eq 100000 ]]
else
    [[ "$INPUT_N" -eq 51701 ]]
fi

rm -rf "$TMP"
mkdir -p "$TMP"

cleanup()
{
    rm -rf "$TMP"
}

trap cleanup EXIT

# ------------------------------------------------------------
# dbCAN 5.2.9
#
# IMPORTANT:
# methods must be supplied in ONE argument.
# ------------------------------------------------------------

/usr/bin/time -v \
  -o "$TMP/time.log" \
  run_dbcan CAZyme_annotation \
    --input_raw_data "$IN" \
    --output_dir "$TMP" \
    --db_dir "$DB" \
    --mode protein \
    --methods diamond,hmm,dbCANsub \
    --threads "$SLURM_CPUS_PER_TASK"

# ------------------------------------------------------------
# Output checks
# ------------------------------------------------------------

OVERVIEW="$TMP/overview.tsv"

[[ -s "$OVERVIEW" ]]
[[ -s "$TMP/dbCAN_hmm_results.tsv" ]]
[[ -s "$TMP/dbCANsub_hmm_results.tsv" ]]
[[ -s "$TMP/diamond.out" ]]

# dbCAN V5 overview.tsv:
# column 6 = #ofTools
HEADER_TOOLS=$(
    awk -F'\t' 'NR==1 {print $6}' "$OVERVIEW"
)

[[ "$HEADER_TOOLS" == "#ofTools" ]]

OVERVIEW_N=$(
    awk -F'\t' '
    NR>1 && NF>0 {n++}
    END {print n+0}
    ' "$OVERVIEW"
)

RECOMMENDED_N=$(
    awk -F'\t' '
    NR>1 && $6+0 >= 2 {n++}
    END {print n+0}
    ' "$OVERVIEW"
)

UNIQUE_OVERVIEW=$(
    awk -F'\t' '
    NR>1 && NF>0 {print $1}
    ' "$OVERVIEW" \
    | LC_ALL=C sort -u \
    | wc -l
)

[[ "$UNIQUE_OVERVIEW" -eq "$OVERVIEW_N" ]]

# ------------------------------------------------------------
# Per-chunk QC
# ------------------------------------------------------------

{
    printf 'chunk\tinput_proteins\toverview_genes\trecommended_genes\n'

    printf 'chunk_%s\t%s\t%s\t%s\n' \
        "$CHUNK" \
        "$INPUT_N" \
        "$OVERVIEW_N" \
        "$RECOMMENDED_N"
} > "$TMP/qc.tsv"

{
    printf 'tools\tgenes\n'

    awk -F'\t' '
    NR>1 && NF>0 {
        n[$6]++
    }
    END {
        for (k in n)
            print k "\t" n[k]
    }
    ' "$OVERVIEW" \
    | LC_ALL=C sort -n
} > "$TMP/tools_distribution.tsv"

# ------------------------------------------------------------
# Mark complete only after every QC check has passed
# ------------------------------------------------------------

touch "$TMP/.dbcan.done"

rm -rf "$OUT"
mv "$TMP" "$OUT"

trap - EXIT

echo "===== chunk_${CHUNK} complete ====="
cat "$OUT/qc.tsv"
cat "$OUT/tools_distribution.tsv"

grep -E \
  'Elapsed \(wall clock\) time|Percent of CPU this job got|Maximum resident set size' \
  "$OUT/time.log"
