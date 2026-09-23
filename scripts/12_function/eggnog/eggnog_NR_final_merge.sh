#!/bin/bash
#SBATCH --job-name=egg_NR_merge
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=06:00:00
#SBATCH --output=logs/eggnog_NR_merge_%j.out
#SBATCH --error=logs/eggnog_NR_merge_%j.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/12_function}"

BASE="$STAGE_DIR"

RESULTS="${BASE}/eggnog/11A/results"
STAGE1="${BASE}/eggnog/11A/stage1_search"
STAGE2="${BASE}/eggnog/11A/stage2_annotation/formal"

FINAL="${BASE}/eggnog/11A/final"

ANN_FINAL="${FINAL}/NR_eggnog_annotations.tsv"
SEED_FINAL="${FINAL}/NR_eggnog_seed_orthologs.tsv"
SUMMARY="${FINAL}/NR_eggnog_summary.tsv"
DONE="${FINAL}/.merge.done"

INPUT_PROTEINS=13151701

FULL_CHUNKS=(
    001 002 003 004 005 006
    008
    011 012 013 014 015
)

mkdir -p "$FINAL"

if [[ -e "$DONE" && -s "$ANN_FINAL" && -s "$SEED_FINAL" ]]; then
    echo "Final merge already complete. Skip."
    exit 0
fi

rm -f \
    "$ANN_FINAL" \
    "$SEED_FINAL" \
    "$SUMMARY" \
    "$DONE"

TMPDIR_LOCAL="/tmp/${USER}/egg_NR_merge_${SLURM_JOB_ID}"
rm -rf "$TMPDIR_LOCAL"
mkdir -p "$TMPDIR_LOCAL"

cleanup() {
    rm -rf "$TMPDIR_LOCAL"
}
trap cleanup EXIT

echo "============================================================"
echo "eggNOG NR final merge"
echo "Node            : $(hostname)"
echo "Input proteins  : ${INPUT_PROTEINS}"
echo "Start           : $(date)"
echo "============================================================"

# ------------------------------------------------------------
# 1. Validate 12 original full-emapper chunks
# ------------------------------------------------------------

echo
echo "===== validate original full chunks ====="

for ID in "${FULL_CHUNKS[@]}"
do
    ANN="${RESULTS}/chunk_${ID}/chunk_${ID}.emapper.annotations"
    SEED="${RESULTS}/chunk_${ID}/chunk_${ID}.emapper.seed_orthologs"

    [[ -s "$ANN" ]] || {
        echo "ERROR: missing annotation: $ANN"
        exit 1
    }

    [[ -s "$SEED" ]] || {
        echo "ERROR: missing seed: $SEED"
        exit 1
    }

    echo "OK chunk_${ID}"
done

# ------------------------------------------------------------
# 2. Validate 120 Stage1 chunks
# ------------------------------------------------------------

S1_DONE=$(
    find "$STAGE1" \
      -mindepth 2 -maxdepth 2 \
      -name '.search.done' \
    | wc -l
)

echo
echo "Stage1 completed chunks: $S1_DONE"

[[ "$S1_DONE" -eq 120 ]] || {
    echo "ERROR: expected 120 Stage1 chunks"
    exit 1
}

# ------------------------------------------------------------
# 3. Validate 12 Stage2 batches
# ------------------------------------------------------------

S2_DONE=$(
    find "$STAGE2" \
      -mindepth 2 -maxdepth 2 \
      -name '.annotation.done' \
    | wc -l
)

echo "Stage2 completed batches: $S2_DONE"

[[ "$S2_DONE" -eq 12 ]] || {
    echo "ERROR: expected 12 Stage2 batches"
    exit 1
}

for B in $(seq -w 1 12)
do
    ANN="${STAGE2}/batch_${B}/batch_${B}.emapper.annotations"

    [[ -s "$ANN" ]] || {
        echo "ERROR: missing Stage2 annotation: $ANN"
        exit 1
    }
done

# ------------------------------------------------------------
# 4. Merge seed orthologs
#
# Use all 132 original per-chunk seed files.
# For each chunk:
#   - original full result if it exists there
#   - otherwise Stage1 search result
#
# This preserves natural chunk order.
# ------------------------------------------------------------

echo
echo "===== merge seed orthologs ====="

FIRST_SEED="${RESULTS}/chunk_001/chunk_001.emapper.seed_orthologs"

{
    echo "## eggNOG-mapper seed orthologs"
    echo "## Merged NR gene catalog: 132 chunks"
    echo "## eggNOG-mapper 2.1.15 / eggNOG 5.0.2"
    grep '^#' "$FIRST_SEED" | tail -1
} > "$SEED_FINAL"

SEED_TOTAL=0
SEED_SOURCES=0

for N in $(seq 1 132)
do
    ID=$(printf "%03d" "$N")

    FULL_SEED="${RESULTS}/chunk_${ID}/chunk_${ID}.emapper.seed_orthologs"
    S1_SEED="${STAGE1}/chunk_${ID}/chunk_${ID}.emapper.seed_orthologs"

    if [[ -s "$FULL_SEED" ]]; then
        SRC="$FULL_SEED"
    elif [[ -s "$S1_SEED" ]]; then
        SRC="$S1_SEED"
    else
        echo "ERROR: no seed source for chunk_${ID}"
        exit 1
    fi

    COUNTFILE="${TMPDIR_LOCAL}/seed_${ID}.count"

    awk -v C="$COUNTFILE" '
        !/^#/ {
            print
            n++
        }
        END {
            print n+0 > C
        }
    ' "$SRC" >> "$SEED_FINAL"

    NROWS=$(cat "$COUNTFILE")
    SEED_TOTAL=$((SEED_TOTAL + NROWS))
    SEED_SOURCES=$((SEED_SOURCES + 1))

    echo "chunk_${ID} seed rows: $NROWS"
done

[[ "$SEED_SOURCES" -eq 132 ]] || {
    echo "ERROR: expected 132 seed sources"
    exit 1
}

# ------------------------------------------------------------
# 5. Merge annotations
#
# Sources:
#   12 original full-emapper chunks
# + 12 Stage2 batch annotation files representing 120 chunks
# ------------------------------------------------------------

echo
echo "===== merge annotations ====="

FIRST_ANN="${RESULTS}/chunk_001/chunk_001.emapper.annotations"

{
    echo "## eggNOG-mapper annotations"
    echo "## Merged NR gene catalog: 132 chunks"
    echo "## 12 original full-emapper chunks + 120 Stage2 annotation-only chunks"
    echo "## eggNOG-mapper 2.1.15 / eggNOG 5.0.2"
    grep '^#query' "$FIRST_ANN" | head -1
} > "$ANN_FINAL"

ANN_TOTAL=0

# Original 12 chunks
for ID in "${FULL_CHUNKS[@]}"
do
    SRC="${RESULTS}/chunk_${ID}/chunk_${ID}.emapper.annotations"
    COUNTFILE="${TMPDIR_LOCAL}/ann_full_${ID}.count"

    awk -v C="$COUNTFILE" '
        !/^#/ {
            print
            n++
        }
        END {
            print n+0 > C
        }
    ' "$SRC" >> "$ANN_FINAL"

    NROWS=$(cat "$COUNTFILE")
    ANN_TOTAL=$((ANN_TOTAL + NROWS))

    echo "chunk_${ID} annotation rows: $NROWS"
done

# Stage2: 12 batches = remaining 120 chunks
for B in $(seq -w 1 12)
do
    SRC="${STAGE2}/batch_${B}/batch_${B}.emapper.annotations"
    COUNTFILE="${TMPDIR_LOCAL}/ann_batch_${B}.count"

    awk -v C="$COUNTFILE" '
        !/^#/ {
            print
            n++
        }
        END {
            print n+0 > C
        }
    ' "$SRC" >> "$ANN_FINAL"

    NROWS=$(cat "$COUNTFILE")
    ANN_TOTAL=$((ANN_TOTAL + NROWS))

    echo "batch_${B} annotation rows: $NROWS"
done

# ------------------------------------------------------------
# 6. Sanity checks
# ------------------------------------------------------------

echo
echo "===== validation ====="

echo "Input proteins       : $INPUT_PROTEINS"
echo "Seed ortholog rows   : $SEED_TOTAL"
echo "Annotation rows      : $ANN_TOTAL"

[[ "$SEED_TOTAL" -le "$INPUT_PROTEINS" ]] || {
    echo "ERROR: seed rows exceed input proteins"
    exit 1
}

[[ "$ANN_TOTAL" -le "$SEED_TOTAL" ]] || {
    echo "ERROR: annotation rows exceed seed rows"
    exit 1
}

SEED_RATE=$(
    awk -v n="$SEED_TOTAL" -v d="$INPUT_PROTEINS" \
        'BEGIN{printf "%.4f", 100*n/d}'
)

ANN_RATE=$(
    awk -v n="$ANN_TOTAL" -v d="$INPUT_PROTEINS" \
        'BEGIN{printf "%.4f", 100*n/d}'
)

# ------------------------------------------------------------
# 7. Summary
# ------------------------------------------------------------

{
    printf 'metric\tvalue\n'
    printf 'input_proteins\t%s\n' "$INPUT_PROTEINS"
    printf 'total_chunks\t132\n'
    printf 'original_full_chunks\t12\n'
    printf 'stage2_chunks\t120\n'
    printf 'stage2_batches\t12\n'
    printf 'seed_ortholog_queries\t%s\n' "$SEED_TOTAL"
    printf 'annotated_queries\t%s\n' "$ANN_TOTAL"
    printf 'seed_ortholog_rate_percent\t%s\n' "$SEED_RATE"
    printf 'annotation_rate_percent\t%s\n' "$ANN_RATE"
    printf 'eggnog_mapper_version\t2.1.15\n'
    printf 'eggnog_database_version\t5.0.2\n'
} > "$SUMMARY"

touch "$DONE"

echo
echo "===== final files ====="
ls -lh \
    "$ANN_FINAL" \
    "$SEED_FINAL" \
    "$SUMMARY"

echo
echo "===== summary ====="
cat "$SUMMARY"

echo
echo "============================================================"
echo "FINAL MERGE COMPLETED"
echo "Finish: $(date)"
echo "============================================================"
