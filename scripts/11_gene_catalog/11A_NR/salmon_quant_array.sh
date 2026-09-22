#!/bin/bash
#SBATCH --job-name=salmon_quant
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=03:00:00
#SBATCH --array=1-60%8
#SBATCH --output=logs/salmon_%A_%a.out
#SBATCH --error=logs/salmon_%A_%a.err

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:?Set PROJECT_ROOT to the repository root}"
WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/11_gene_catalog/11A_NR}"
DEHOST_ROOT="${DEHOST_ROOT:-$WORK_ROOT/02_dehost}"
SAMPLE_LIST="${SAMPLE_LIST:-$PROJECT_ROOT/config/samples.txt}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate gene_catalog

# ============================================================
# sample
# ============================================================

S=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

if [[ -z "$S" ]]; then
    echo "ERROR: cannot determine sample"
    exit 1
fi

INDEX="$STAGE_DIR/salmon/NR_gene_index"

R1="$DEHOST_ROOT/$S/${S}_R1.dehost.fq.gz"
R2="$DEHOST_ROOT/$S/${S}_R2.dehost.fq.gz"

OUT="$STAGE_DIR/salmon/quant/$S"
TMP="$STAGE_DIR/salmon/quant/${S}.tmp"

EXPECTED=13151701
EXPECTED_LINES=$((EXPECTED + 1))

echo "============================================================"
echo "Salmon gene quantification"
echo "============================================================"
echo "Sample : $S"
echo "Node   : $(hostname)"
echo "CPUs   : $SLURM_CPUS_PER_TASK"
echo "Memory : 32G"
echo "Start  : $(date)"
echo "============================================================"

# ============================================================
# checkpoint
# ============================================================

if [[ -f "$OUT/.salmon.done" && -s "$OUT/quant.sf" ]]; then

    N=$(wc -l < "$OUT/quant.sf")

    if [[ "$N" -eq "$EXPECTED_LINES" ]]; then
        echo "$S already complete, skip."
        echo "quant.sf lines : $N"
        exit 0
    fi
fi

# ============================================================
# input checks
# ============================================================

[[ -s "$INDEX/info.json" ]] || {
    echo "ERROR: Salmon index missing"
    exit 1
}

[[ -s "$R1" ]] || {
    echo "ERROR: missing R1: $R1"
    exit 1
}

[[ -s "$R2" ]] || {
    echo "ERROR: missing R2: $R2"
    exit 1
}

# ============================================================
# clean incomplete run
# ============================================================

rm -rf "$TMP"
mkdir -p "$TMP"

# ============================================================
# Salmon quant
# ============================================================

/usr/bin/time -v \
    -o "$TMP/${S}.salmon.time.log" \
    salmon quant \
        -i "$INDEX" \
        -l A \
        -1 "$R1" \
        -2 "$R2" \
        -p "$SLURM_CPUS_PER_TASK" \
        --meta \
        -o "$TMP" \
        > "$TMP/${S}.salmon.log" 2>&1

# ============================================================
# output QC
# ============================================================

QUANT="$TMP/quant.sf"

[[ -s "$QUANT" ]] || {
    echo "ERROR: quant.sf missing"
    exit 1
}

LINES=$(wc -l < "$QUANT")

echo
echo "Expected quant.sf lines : $EXPECTED_LINES"
echo "Actual quant.sf lines   : $LINES"

if [[ "$LINES" -ne "$EXPECTED_LINES" ]]; then
    echo "ERROR: quant.sf line count mismatch"
    exit 1
fi

# ============================================================
# extract mapping statistics from Salmon log
# ============================================================

MAPLINE=$(grep -E \
    'deterministic: mapped [0-9]+ / [0-9]+ fragments' \
    "$TMP/${S}.salmon.log" | tail -n 1 || true)

if [[ -n "$MAPLINE" ]]; then

    MAPPED=$(echo "$MAPLINE" | sed -E \
        's/.*mapped ([0-9]+) \/ ([0-9]+) fragments \(([0-9.]+)%\).*/\1/')

    TOTAL=$(echo "$MAPLINE" | sed -E \
        's/.*mapped ([0-9]+) \/ ([0-9]+) fragments \(([0-9.]+)%\).*/\2/')

    RATE=$(echo "$MAPLINE" | sed -E \
        's/.*mapped ([0-9]+) \/ ([0-9]+) fragments \(([0-9.]+)%\).*/\3/')

else

    MAPPED="NA"
    TOTAL="NA"
    RATE="NA"

fi

printf "Sample\tTotal_fragments\tMapped_fragments\tMapping_rate_percent\n" \
    > "$TMP/${S}.salmon_summary.tsv"

printf "%s\t%s\t%s\t%s\n" \
    "$S" "$TOTAL" "$MAPPED" "$RATE" \
    >> "$TMP/${S}.salmon_summary.tsv"

# ============================================================
# finalize atomically
# ============================================================

rm -rf "$OUT"
mv "$TMP" "$OUT"

touch "$OUT/.salmon.done"

# ============================================================
# report
# ============================================================

echo
echo "===== mapping ====="
cat "$OUT/${S}.salmon_summary.tsv"

echo
echo "===== quant.sf ====="
ls -lh "$OUT/quant.sf"

echo
echo "Finish : $(date)"
echo "============================================================"
