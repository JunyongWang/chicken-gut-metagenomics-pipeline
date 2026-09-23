#!/bin/bash
#SBATCH --job-name=split_NR_eggnog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=logs/split_NR_eggnog_%j.out
#SBATCH --error=logs/split_NR_eggnog_%j.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/12_function}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
NR_PROTEIN_CATALOG="${NR_PROTEIN_CATALOG:-$WORK_ROOT/11_gene_catalog/11A_NR/nr/NR_gene_catalog.faa}"

cd "$STAGE_DIR"

IN="$NR_PROTEIN_CATALOG"
OUTDIR="$STAGE_DIR/eggnog/11A/chunks"

mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/chunk_*.faa "$STAGE_DIR/eggnog/11A/chunks.txt"

echo "============================================================"
echo "Split NR proteins for eggNOG"
echo "Node  : $(hostname)"
echo "Start : $(date)"
echo "============================================================"

awk -v outdir="$OUTDIR" '
/^>/ {
    n++

    if ((n-1)%100000==0) {
        if (out!="") close(out)

        part=sprintf("%03d", int((n-1)/100000)+1)
        out=outdir "/chunk_" part ".faa"
    }
}
{
    print > out
}
' "$IN"

find "$OUTDIR" \
    -maxdepth 1 \
    -name 'chunk_*.faa' \
    -printf '%f\n' \
| sort > "$STAGE_DIR/eggnog/11A/chunks.txt"

NCHUNK=$(wc -l < "$STAGE_DIR/eggnog/11A/chunks.txt")

TOTAL=$(grep -h '^>' "$OUTDIR"/chunk_*.faa | wc -l)

echo
echo "Chunks   : $NCHUNK"
echo "Proteins : $TOTAL"

if [[ "$NCHUNK" -ne 132 ]]; then
    echo "ERROR: expected 132 chunks"
    exit 1
fi

if [[ "$TOTAL" -ne 13151701 ]]; then
    echo "ERROR: expected 13151701 proteins"
    exit 1
fi

echo
echo "===== per chunk ====="

for F in "$OUTDIR"/chunk_*.faa
do
    printf "%s\t" "$(basename "$F")"
    grep -c '^>' "$F"
done

touch "$STAGE_DIR/eggnog/11A/.split.done"

echo
echo "Finish : $(date)"
echo "============================================================"

