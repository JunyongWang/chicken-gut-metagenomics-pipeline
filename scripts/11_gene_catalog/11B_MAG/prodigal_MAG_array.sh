#!/bin/bash
#SBATCH --job-name=mag_prodigal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --array=1-374%40
#SBATCH --output=logs/mag_prodigal_%A_%a.out
#SBATCH --error=logs/mag_prodigal_%A_%a.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/11_gene_catalog/11B_MAG}"
MAG_DIR="${MAG_DIR:?Set MAG_DIR to the 374 representative MAG directory}"
MAG_LIST="${MAG_LIST:?Set MAG_LIST to the ordered 374-MAG manifest}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate gene_catalog

MAG=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$MAG_LIST")

if [[ -z "$MAG" ]]; then
    echo "ERROR: cannot determine MAG"
    exit 1
fi

IN="$MAG_DIR/${MAG}.fa"
OUT="$STAGE_DIR/prodigal/$MAG"

PREFIXED="$OUT/${MAG}.prefixed.fa"

FFN="$OUT/${MAG}.genes.ffn"
FAA="$OUT/${MAG}.genes.faa"
GFF="$OUT/${MAG}.genes.gff"

QC="$OUT/${MAG}.prodigal_qc.tsv"
DONE="$OUT/.prodigal.done"

mkdir -p "$OUT"

echo "============================================================"
echo "MAG Prodigal gene prediction"
echo "MAG   : $MAG"
echo "Node  : $(hostname)"
echo "Start : $(date)"
echo "============================================================"

# ------------------------------------------------------------
# checkpoint
# ------------------------------------------------------------

if [[ -f "$DONE" && -s "$FFN" && -s "$FAA" && -s "$GFF" ]]; then

    N1=$(grep -c '^>' "$FFN")
    N2=$(grep -c '^>' "$FAA")

    if [[ "$N1" -gt 0 && "$N1" -eq "$N2" ]]; then
        echo "$MAG already complete, skip."
        echo "Genes : $N1"
        exit 0
    fi
fi

# ------------------------------------------------------------
# input check
# ------------------------------------------------------------

if [[ ! -s "$IN" ]]; then
    echo "ERROR: missing input: $IN"
    exit 1
fi

rm -f \
    "$DONE" \
    "$PREFIXED" \
    "$FFN" \
    "$FAA" \
    "$GFF" \
    "$QC"

# ------------------------------------------------------------
# 1. Prefix contig IDs with MAG name
# ------------------------------------------------------------

awk -v p="$MAG" '
/^>/ {
    sub(/^>/, ">" p "__")
}
{print}
' "$IN" > "$PREFIXED"

# ------------------------------------------------------------
# 2. Prodigal single-genome mode
# ------------------------------------------------------------

/usr/bin/time -v \
    -o "$OUT/${MAG}.time.log" \
    prodigal \
        -i "$PREFIXED" \
        -p single \
        -f gff \
        -d "$FFN" \
        -a "$FAA" \
        -o "$GFF" \
        2> "$OUT/${MAG}.prodigal.log"

# ------------------------------------------------------------
# 3. QC
# ------------------------------------------------------------

FFN_N=$(grep -c '^>' "$FFN")
FAA_N=$(grep -c '^>' "$FAA")

if [[ "$FFN_N" -eq 0 ]]; then
    echo "ERROR: zero genes predicted"
    exit 1
fi

if [[ "$FFN_N" -ne "$FAA_N" ]]; then
    echo "ERROR: FFN/FAA counts differ"
    exit 1
fi

printf "MAG\tGenes\tProteins\n" > "$QC"

printf "%s\t%s\t%s\n" \
    "$MAG" "$FFN_N" "$FAA_N" >> "$QC"

# ------------------------------------------------------------
# 4. Remove temporary prefixed MAG
# ------------------------------------------------------------

rm -f "$PREFIXED"

touch "$DONE"

echo
echo "Genes predicted    : $FFN_N"
echo "Proteins predicted : $FAA_N"
echo "Finish             : $(date)"
echo "============================================================"
