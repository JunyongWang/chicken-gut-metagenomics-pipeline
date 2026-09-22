#!/bin/bash
#SBATCH --job-name=merge_genes
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=logs/merge_genes_%j.out
#SBATCH --error=logs/merge_genes_%j.err

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:?Set PROJECT_ROOT to the repository root}"
WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/11_gene_catalog/11A_NR}"
SAMPLE_LIST="${SAMPLE_LIST:-$PROJECT_ROOT/config/samples.txt}"

cd "$STAGE_DIR"

OUTDIR="$STAGE_DIR/nr"
OUT="$OUTDIR/all_genes.min100.ffn"
TMP="$OUTDIR/all_genes.min100.ffn.tmp"
DONE="$OUTDIR/.merge_ffn.done"

mkdir -p "$OUTDIR"

EXPECTED=$(awk -F'\t' '
NR>1 {sum += $3}
END {printf "%.0f", sum}
' prodigal_summary.tsv)

echo "============================================================"
echo "Merge filtered nucleotide genes"
echo "Node     : $(hostname)"
echo "Start    : $(date)"
echo "Expected : $EXPECTED"
echo "============================================================"

if [[ "$EXPECTED" -ne 28098350 ]]; then
    echo "ERROR: unexpected total gene count: $EXPECTED"
    exit 1
fi

rm -f "$TMP" "$DONE"

N_SAMPLE=0

while read -r S
do
    F="prodigal/$S/${S}.genes.min100.ffn"

    if [[ ! -s "$F" ]]; then
        echo "ERROR: missing $F"
        exit 1
    fi

    cat "$F" >> "$TMP"

    N_SAMPLE=$((N_SAMPLE + 1))
    echo "Merged: $S"
done < "$SAMPLE_LIST"

if [[ "$N_SAMPLE" -ne 60 ]]; then
    echo "ERROR: expected 60 samples, got $N_SAMPLE"
    exit 1
fi

ACTUAL=$(grep -c '^>' "$TMP")

echo
echo "Samples merged : $N_SAMPLE"
echo "Expected genes : $EXPECTED"
echo "Actual genes   : $ACTUAL"

if [[ "$ACTUAL" -ne "$EXPECTED" ]]; then
    echo "ERROR: merged gene count mismatch"
    exit 1
fi

mv "$TMP" "$OUT"
touch "$DONE"

echo
ls -lh "$OUT"

echo
echo "Finish : $(date)"
echo "============================================================"
