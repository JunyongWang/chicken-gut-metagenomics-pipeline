#!/bin/bash
#SBATCH --job-name=cazy_NR_abund
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --output=logs/cazy_NR_abund_%j.out
#SBATCH --error=logs/cazy_NR_abund_%j.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/12_function}"
PYTHON="${PYTHON:-python3}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${CAZYME_AGGREGATOR:-$SCRIPT_DIR/aggregate_dbcan_NR_family.py}"
REC="${NR_DBCAN_RECOMMENDED:-$STAGE_DIR/dbcan/11A/final/NR_dbcan_recommended.tsv}"
TPM="${GENE_TPM:-$WORK_ROOT/11_gene_catalog/11A_NR/salmon/matrices/Gene_TPM.tsv}"
NUM="${GENE_NUMREADS:-$WORK_ROOT/11_gene_catalog/11A_NR/salmon/matrices/Gene_NumReads.tsv}"
OUT="${NR_CAZYME_OUT:-$STAGE_DIR/dbcan/11A/abundance}"
TMP="${STAGE_DIR}/dbcan/11A/.abundance.tmp.${SLURM_JOB_ID}"

cd "$STAGE_DIR"

mkdir -p logs

if [[ -f "$OUT/.abundance.done" ]]; then
    echo "12B-3 already complete"
    exit 0
fi

[[ -x "$PYTHON" ]]
[[ -s "$SCRIPT" ]]
[[ -s "$REC" ]]
[[ -s "$TPM" ]]
[[ -s "$NUM" ]]

rm -rf "$TMP"
mkdir -p "$TMP"

cleanup()
{
    rm -rf "$TMP"
}

trap cleanup EXIT

/usr/bin/time -v \
    -o "$TMP/time.log" \
    "$PYTHON" \
    "$SCRIPT" \
    "$REC" \
    "$TPM" \
    "$NUM" \
    "$TMP"

# ------------------------------------------------------------
# Frozen structural QC
# ------------------------------------------------------------

[[ "$(wc -l < "$TMP/NR_cazyme_gene_family_map.tsv")" -eq 275207 ]]
[[ "$(wc -l < "$TMP/NR_cazyme_family_gene_counts.tsv")" -eq 292 ]]
[[ "$(wc -l < "$TMP/NR_dbcan_SLH_features.tsv")" -eq 32 ]]

[[ "$(wc -l < "$TMP/NR_cazyme_family_TPM.tsv")" -eq 292 ]]
[[ "$(wc -l < "$TMP/NR_cazyme_family_NumReads.tsv")" -eq 292 ]]

[[ "$(wc -l < "$TMP/NR_cazyme_abundance_QC.tsv")" -eq 61 ]]

[[ -s "$TMP/NR_cazyme_family_summary.tsv" ]]
[[ -s "$TMP/time.log" ]]

rm -rf "$OUT"
mv "$TMP" "$OUT"

trap - EXIT

touch "$OUT/.abundance.done"

echo "===== 12B-3 complete ====="
cat "$OUT/NR_cazyme_family_summary.tsv"

echo
echo "===== output files ====="
ls -lh "$OUT"

echo
echo "===== resource usage ====="
grep -E \
  'Elapsed \(wall clock\) time|Percent of CPU this job got|Maximum resident set size' \
  "$OUT/time.log"
