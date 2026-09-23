#!/bin/bash
#SBATCH --job-name=prodigal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=03:00:00
#SBATCH --array=1-60%20
#SBATCH --output=logs/prodigal_%A_%a.out
#SBATCH --error=logs/prodigal_%A_%a.err

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:?Set PROJECT_ROOT to the repository root}"
WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/11_gene_catalog/11A_NR}"
ASSEMBLY_ROOT="${ASSEMBLY_ROOT:-$WORK_ROOT/04_assembly}"
SAMPLE_LIST="${SAMPLE_LIST:-$PROJECT_ROOT/config/samples.txt}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate gene_catalog

S=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

if [[ -z "$S" ]]; then
    echo "ERROR: cannot determine sample"
    exit 1
fi

IN="$ASSEMBLY_ROOT/$S/$S.final.contigs.fa"
OUT="$STAGE_DIR/prodigal/$S"

PREFIXED="$OUT/${S}.contigs.prefixed.fa"

RAW_FFN="$OUT/${S}.genes.ffn"
RAW_FAA="$OUT/${S}.genes.faa"
GFF="$OUT/${S}.genes.gff"

FINAL_FFN="$OUT/${S}.genes.min100.ffn"
FINAL_FAA="$OUT/${S}.genes.min100.faa"

TMP_FFN="$OUT/${S}.genes.min100.ffn.tmp"
TMP_FAA="$OUT/${S}.genes.min100.faa.tmp"

IDS="$OUT/${S}.genes.min100.ids"
QC="$OUT/${S}.prodigal_qc.tsv"
DONE="$OUT/.prodigal.done"

mkdir -p "$OUT"

echo "============================================================"
echo "Prodigal gene prediction"
echo "Sample : $S"
echo "Node   : $(hostname)"
echo "Start  : $(date)"
echo "============================================================"

# ------------------------------------------------------------
# checkpoint
# ------------------------------------------------------------

if [[ -f "$DONE" && -s "$FINAL_FFN" && -s "$FINAL_FAA" ]]; then

    N1=$(grep -c '^>' "$FINAL_FFN")
    N2=$(grep -c '^>' "$FINAL_FAA")

    if [[ "$N1" -gt 0 && "$N1" -eq "$N2" ]]; then
        echo "$S already complete, skip."
        echo "Genes >=100 bp : $N1"
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
    "$RAW_FFN" \
    "$RAW_FAA" \
    "$TMP_FFN" \
    "$TMP_FAA" \
    "$IDS"

# ------------------------------------------------------------
# 1. Prefix contig IDs
# ------------------------------------------------------------

awk -v s="$S" '
/^>/ {
    sub(/^>/, ">" s "__")
}
{print}
' "$IN" > "$PREFIXED"

# ------------------------------------------------------------
# 2. Prodigal metagenomic gene prediction
# ------------------------------------------------------------

/usr/bin/time -v \
    -o "$OUT/${S}.time.log" \
    prodigal \
        -i "$PREFIXED" \
        -p meta \
        -d "$RAW_FFN" \
        -a "$RAW_FAA" \
        -f gff \
        -o "$GFF" \
        2> "$OUT/${S}.prodigal.log"

# ------------------------------------------------------------
# 3. Keep CDS >=100 bp
# ------------------------------------------------------------

seqkit seq \
    -j "$SLURM_CPUS_PER_TASK" \
    -m 100 \
    "$RAW_FFN" \
    > "$TMP_FFN"

grep '^>' "$TMP_FFN" \
    | sed 's/^>//; s/[[:space:]].*$//' \
    > "$IDS"

seqkit grep \
    -j "$SLURM_CPUS_PER_TASK" \
    -f "$IDS" \
    "$RAW_FAA" \
    > "$TMP_FAA"

# ------------------------------------------------------------
# 4. QC
# ------------------------------------------------------------

RAW_N=$(grep -c '^>' "$RAW_FFN")
FILTER_N=$(grep -c '^>' "$TMP_FFN")
PROTEIN_N=$(grep -c '^>' "$TMP_FAA")

if [[ "$FILTER_N" -eq 0 ]]; then
    echo "ERROR: zero genes retained"
    exit 1
fi

if [[ "$FILTER_N" -ne "$PROTEIN_N" ]]; then
    echo "ERROR: FFN/FAA counts differ"
    exit 1
fi

mv "$TMP_FFN" "$FINAL_FFN"
mv "$TMP_FAA" "$FINAL_FAA"

RETENTION=$(awk -v a="$FILTER_N" -v b="$RAW_N" \
    'BEGIN{printf "%.4f",100*a/b}')

printf "Sample\tRaw_genes\tGenes_ge100\tProteins_ge100\tRetained_percent\n" \
    > "$QC"

printf "%s\t%s\t%s\t%s\t%s\n" \
    "$S" "$RAW_N" "$FILTER_N" "$PROTEIN_N" "$RETENTION" \
    >> "$QC"

# ------------------------------------------------------------
# 5. Remove redundant intermediate FASTA files
# ------------------------------------------------------------

rm -f \
    "$PREFIXED" \
    "$RAW_FFN" \
    "$RAW_FAA"

touch "$DONE"

echo
echo "Raw genes       : $RAW_N"
echo "Genes >=100 bp  : $FILTER_N"
echo "Proteins kept   : $PROTEIN_N"
echo "Retention (%)   : $RETENTION"
echo "Finish          : $(date)"
echo "============================================================"
