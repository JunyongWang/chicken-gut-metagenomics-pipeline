#!/bin/bash
#SBATCH --job-name=NR_KO
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=logs/NR_KO_%j.out
#SBATCH --error=logs/NR_KO_%j.err

set -euo pipefail

STAGE_DIR="${STAGE_DIR:-${SLURM_SUBMIT_DIR:-$PWD}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"

export NR_EGGNOG_ANNOTATIONS="${NR_EGGNOG_ANNOTATIONS:-$STAGE_DIR/eggnog/11A/final/NR_eggnog_annotations.tsv}"
export GENE_TPM="${GENE_TPM:-$STAGE_DIR/../11_gene_catalog/salmon/matrices/Gene_TPM.tsv}"
export GENE_NUMREADS="${GENE_NUMREADS:-$STAGE_DIR/../11_gene_catalog/salmon/matrices/Gene_NumReads.tsv}"
export NR_KO_OUT="${NR_KO_OUT:-$STAGE_DIR/eggnog/11A/ko_abundance}"

cd "$STAGE_DIR"
mkdir -p logs

rm -rf "$NR_KO_OUT"

/usr/bin/time -v \
  -o "logs/NR_KO_time_${SLURM_JOB_ID:-manual}.log" \
  "$PYTHON_BIN" "$SCRIPT_DIR/aggregate_NR_KO.py"

touch "$NR_KO_OUT/.ko_abundance.done"

echo "===== summary ====="
cat "$NR_KO_OUT/NR_KO_summary.tsv"
