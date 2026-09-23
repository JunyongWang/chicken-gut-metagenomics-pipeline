#!/bin/bash
#SBATCH --job-name=NR_protein
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=logs/NR_protein_%j.out
#SBATCH --error=logs/NR_protein_%j.err

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:?Set PROJECT_ROOT to the repository root}"
WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/11_gene_catalog/11A_NR}"
SAMPLE_LIST="${SAMPLE_LIST:-$PROJECT_ROOT/config/samples.txt}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate gene_catalog

NRDIR="$STAGE_DIR/nr"

FFN="$NRDIR/NR_gene_catalog.ffn"
IDS="$NRDIR/NR_gene_catalog.ids"

OUT="$NRDIR/NR_gene_catalog.faa"
TMP="$NRDIR/NR_gene_catalog.faa.tmp"

DONE="$NRDIR/.nr_protein.done"

EXPECTED=13151701

echo "============================================================"
echo "Extract NR protein catalog"
echo "Node     : $(hostname)"
echo "CPUs     : $SLURM_CPUS_PER_TASK"
echo "Expected : $EXPECTED"
echo "Start    : $(date)"
echo "============================================================"

[[ -s "$FFN" ]] || {
    echo "ERROR: missing $FFN"
    exit 1
}

# ------------------------------------------------------------
# checkpoint
# ------------------------------------------------------------

if [[ -f "$DONE" && -s "$OUT" ]]; then
    N=$(grep -c '^>' "$OUT")

    if [[ "$N" -eq "$EXPECTED" ]]; then
        echo "NR protein catalog already complete."
        exit 0
    fi
fi

rm -f "$TMP" "$DONE"

# ------------------------------------------------------------
# 1. Representative gene IDs
# ------------------------------------------------------------

seqkit seq \
    -n -i \
    "$FFN" \
    > "$IDS"

ID_N=$(wc -l < "$IDS")

echo "Representative IDs : $ID_N"

if [[ "$ID_N" -ne "$EXPECTED" ]]; then
    echo "ERROR: representative ID count mismatch"
    exit 1
fi

# ------------------------------------------------------------
# 2. Build list of 60 protein FASTA files
# ------------------------------------------------------------

FILES=()

while read -r S
do
    F="$STAGE_DIR/prodigal/$S/${S}.genes.min100.faa"

    if [[ ! -s "$F" ]]; then
        echo "ERROR: missing $F"
        exit 1
    fi

    FILES+=("$F")
done < "$SAMPLE_LIST"

if [[ "${#FILES[@]}" -ne 60 ]]; then
    echo "ERROR: expected 60 protein files"
    exit 1
fi

echo "Protein files      : ${#FILES[@]}"

# ------------------------------------------------------------
# 3. Extract proteins corresponding to NR nucleotide genes
# ------------------------------------------------------------

/usr/bin/time -v \
    -o "$NRDIR/extract_nr_proteins.time.log" \
    seqkit grep \
        -j "$SLURM_CPUS_PER_TASK" \
        -f "$IDS" \
        "${FILES[@]}" \
        > "$TMP" \
        2> "$NRDIR/extract_nr_proteins.log"

# ------------------------------------------------------------
# 4. QC
# ------------------------------------------------------------

PROTEIN_N=$(grep -c '^>' "$TMP")

echo
echo "Expected proteins : $EXPECTED"
echo "Extracted proteins: $PROTEIN_N"

if [[ "$PROTEIN_N" -ne "$EXPECTED" ]]; then
    echo "ERROR: NR protein count mismatch"
    exit 1
fi

mv "$TMP" "$OUT"

touch "$DONE"

echo
echo "===== final ====="
ls -lh "$FFN" "$OUT" "$IDS"

echo
echo "Finish : $(date)"
echo "============================================================"
