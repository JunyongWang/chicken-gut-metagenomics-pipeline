#!/bin/bash
#SBATCH --job-name=split_dbcan_MAG
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=logs/split_dbcan_MAG_%j.out
#SBATCH --error=logs/split_dbcan_MAG_%j.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/12_function}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
MAG_PROTEIN_CATALOG="${MAG_PROTEIN_CATALOG:-$WORK_ROOT/11_gene_catalog/11B_MAG/catalog/MAG_gene_catalog.faa}"

cd "$STAGE_DIR"

IN="$MAG_PROTEIN_CATALOG"
OUTDIR="$STAGE_DIR/dbcan/11B/chunks"

rm -f "$OUTDIR"/chunk_*.faa
rm -f "$STAGE_DIR/dbcan/11B/chunks.txt"

awk -v outdir="$OUTDIR" '
/^>/ {
    n++
    if ((n-1)%100000==0) {
        if (out!="") close(out)
        part=sprintf("%03d",int((n-1)/100000)+1)
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
  | sort -V \
  > "$STAGE_DIR/dbcan/11B/chunks.txt"

N=$(wc -l < "$STAGE_DIR/dbcan/11B/chunks.txt")
TOTAL=$(grep -h '^>' "$OUTDIR"/chunk_*.faa | wc -l)

[[ "$N" -eq 7 ]]
[[ "$TOTAL" -eq 688771 ]]

touch "$STAGE_DIR/dbcan/11B/.split.done"
