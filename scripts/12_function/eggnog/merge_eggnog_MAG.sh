#!/bin/bash
#SBATCH --job-name=merge_eggnog_MAG
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=logs/merge_eggnog_MAG_%j.out
#SBATCH --error=logs/merge_eggnog_MAG_%j.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/12_function}"

cd "$STAGE_DIR"

INDIR="eggnog/11B/results"
OUTDIR="eggnog/11B/final"

mkdir -p "$OUTDIR"

ANN="$OUTDIR/MAG_eggnog_annotations.tsv"
SEED="$OUTDIR/MAG_eggnog_seed_orthologs.tsv"
SUMMARY="$OUTDIR/MAG_eggnog_summary.tsv"

ANN_TMP="${ANN}.tmp"
SEED_TMP="${SEED}.tmp"

rm -f "$ANN_TMP" "$SEED_TMP" "$SUMMARY"

echo "============================================================"
echo "Merge MAG eggNOG results"
echo "Node  : $(hostname)"
echo "Start : $(date)"
echo "============================================================"

TOTAL_INPUT=0
TOTAL_ANNOTATED=0
TOTAL_SEED=0

FIRST=1

for i in 001 002 003 004 005 006 007
do
    D="$INDIR/chunk_${i}"

    A="$D/chunk_${i}.emapper.annotations"
    S="$D/chunk_${i}.emapper.seed_orthologs"
    Q="$D/chunk_${i}.qc.tsv"
    DONE="$D/.eggnog.done"

    [[ -f "$DONE" ]] || {
        echo "ERROR: chunk_${i} not complete"
        exit 1
    }

    [[ -s "$A" ]] || {
        echo "ERROR: missing annotations: $A"
        exit 1
    }

    [[ -s "$S" ]] || {
        echo "ERROR: missing seed orthologs: $S"
        exit 1
    }

    [[ -s "$Q" ]] || {
        echo "ERROR: missing QC: $Q"
        exit 1
    }

    INPUT_N=$(awk -F'\t' 'NR==2{print $2}' "$Q")
    ANN_N=$(awk -F'\t' 'NR==2{print $3}' "$Q")
    SEED_N=$(awk -F'\t' 'NR==2{print $4}' "$Q")

    TOTAL_INPUT=$((TOTAL_INPUT + INPUT_N))
    TOTAL_ANNOTATED=$((TOTAL_ANNOTATED + ANN_N))
    TOTAL_SEED=$((TOTAL_SEED + SEED_N))

    if [[ "$FIRST" -eq 1 ]]; then
        grep '^#query' "$A" > "$ANN_TMP"
        FIRST=0
    fi

    grep -v '^#' "$A" >> "$ANN_TMP"

    grep -v '^#' "$S" >> "$SEED_TMP"

    echo "Merged chunk_${i}: input=$INPUT_N annotated=$ANN_N"
done

if [[ "$TOTAL_INPUT" -ne 688771 ]]; then
    echo "ERROR: expected 688771 proteins, got $TOTAL_INPUT"
    exit 1
fi

MERGED_ANN=$(grep -v '^#' "$ANN_TMP" | awk 'NF>0' | wc -l)
MERGED_SEED=$(awk 'NF>0' "$SEED_TMP" | wc -l)

if [[ "$MERGED_ANN" -ne "$TOTAL_ANNOTATED" ]]; then
    echo "ERROR: annotation row mismatch"
    exit 1
fi

if [[ "$MERGED_SEED" -ne "$TOTAL_SEED" ]]; then
    echo "ERROR: seed row mismatch"
    exit 1
fi

mv "$ANN_TMP" "$ANN"
mv "$SEED_TMP" "$SEED"

printf "Metric\tValue\n" > "$SUMMARY"
printf "Input_proteins\t%s\n" "$TOTAL_INPUT" >> "$SUMMARY"
printf "Annotated_proteins\t%s\n" "$TOTAL_ANNOTATED" >> "$SUMMARY"
printf "Seed_orthologs\t%s\n" "$TOTAL_SEED" >> "$SUMMARY"

awk -v n="$TOTAL_INPUT" -v a="$TOTAL_ANNOTATED" \
    'BEGIN{printf "Annotation_rate_percent\t%.4f\n",100*a/n}' \
    >> "$SUMMARY"

touch "$OUTDIR/.merge_eggnog_MAG.done"

echo
echo "===== FINAL QC ====="
cat "$SUMMARY"

echo
echo "===== FILES ====="
ls -lh "$ANN" "$SEED" "$SUMMARY"

echo
echo "Finish : $(date)"
echo "============================================================"

