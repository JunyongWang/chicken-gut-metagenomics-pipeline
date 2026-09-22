#!/bin/bash
#SBATCH --job-name=merge_salmon
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --output=logs/merge_salmon_%j.out
#SBATCH --error=logs/merge_salmon_%j.err

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:?Set PROJECT_ROOT to the repository root}"
WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/11_gene_catalog/11A_NR}"
SAMPLE_LIST="${SAMPLE_LIST:-$PROJECT_ROOT/config/samples.txt}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
export STAGE_DIR SAMPLE_LIST

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate gene_catalog

OUTDIR="$STAGE_DIR/salmon/matrices"
DONE="$OUTDIR/.merge_salmon.done"

mkdir -p "$OUTDIR"

echo "============================================================"
echo "Merge Salmon abundance matrices"
echo "Node  : $(hostname)"
echo "Start : $(date)"
echo "============================================================"

rm -f "$DONE"

/usr/bin/time -v \
    -o "$OUTDIR/merge_salmon.time.log" \
    "$PYTHON_BIN" "$STAGE_DIR/merge_salmon.py"

TPM="$OUTDIR/Gene_TPM.tsv"
READS="$OUTDIR/Gene_NumReads.tsv"

[[ -s "$TPM" ]] || {
    echo "ERROR: Gene_TPM.tsv missing"
    exit 1
}

[[ -s "$READS" ]] || {
    echo "ERROR: Gene_NumReads.tsv missing"
    exit 1
}

TPM_LINES=$(wc -l < "$TPM")
READ_LINES=$(wc -l < "$READS")

EXPECTED_LINES=13151702

echo
echo "TPM lines      : $TPM_LINES"
echo "NumReads lines : $READ_LINES"

if [[ "$TPM_LINES" -ne "$EXPECTED_LINES" ]]; then
    echo "ERROR: Gene_TPM.tsv line count mismatch"
    exit 1
fi

if [[ "$READ_LINES" -ne "$EXPECTED_LINES" ]]; then
    echo "ERROR: Gene_NumReads.tsv line count mismatch"
    exit 1
fi

touch "$DONE"

echo
echo "===== final matrices ====="
ls -lh "$TPM" "$READS"

echo
echo "Finish : $(date)"
echo "============================================================"
