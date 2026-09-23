#!/bin/bash
#SBATCH --job-name=egg_S1_retry
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G
#SBATCH --time=24:00:00
#SBATCH --output=logs/eggnog_S1_retry_%A_%a.out
#SBATCH --error=logs/eggnog_S1_retry_%A_%a.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/12_function}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
EGGNOG_ENV="${EGGNOG_ENV:-eggnog}"
EGGNOG_DATA="${EGGNOG_DATA:?Set EGGNOG_DATA to the eggNOG-mapper 5.0.2 data directory}"
source "$CONDA_SH"
conda activate "$EGGNOG_ENV"

BASE="$STAGE_DIR"
DATA="$EGGNOG_DATA"

ID=$(printf "%03d" "$SLURM_ARRAY_TASK_ID")
BASE_NAME="chunk_${ID}"

IN="${BASE}/eggnog/11A/chunks/${BASE_NAME}.faa"

OUTDIR="${BASE}/eggnog/11A/stage1_search/${BASE_NAME}"

DONE="${OUTDIR}/.search.done"

LOCAL_TMP="${TMPDIR:-/tmp}/${USER:-user}/eggnog_S1_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"

echo "============================================================"
echo "eggNOG Stage 1: DIAMOND-only search"
echo "Chunk      : $BASE_NAME"
echo "Job        : ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
echo "Node       : $(hostname)"
echo "CPU        : $SLURM_CPUS_PER_TASK"
echo "Input      : $IN"
echo "Database   : $DATA"
echo "Output     : $OUTDIR"
echo "Local tmp  : $LOCAL_TMP"
echo "Start      : $(date)"
echo "============================================================"

# ------------------------------------------------------------
# Input checks
# ------------------------------------------------------------

if [[ ! -s "$IN" ]]; then
    echo "ERROR: input missing or empty:"
    echo "$IN"
    exit 1
fi

for F in eggnog.db eggnog.taxa.db eggnog_proteins.dmnd
do
    if [[ ! -s "${DATA}/${F}" ]]; then
        echo "ERROR: database file missing or empty:"
        echo "${DATA}/${F}"
        exit 1
    fi
done

if [[ ! -e "${DATA}/.copy_complete" ]]; then
    echo "ERROR: database copy marker missing:"
    echo "${DATA}/.copy_complete"
    exit 1
fi

# ------------------------------------------------------------
# Skip genuinely completed Stage 1 chunks
# ------------------------------------------------------------

if [[ -e "$DONE" ]]; then
    echo "Stage 1 already completed: $BASE_NAME"
    echo "Skip."
    exit 0
fi

# ------------------------------------------------------------
# No resume:
# incomplete Stage 1 output is removed and rerun fresh
# ------------------------------------------------------------

if [[ -d "$OUTDIR" ]]; then
    echo "Removing incomplete Stage 1 output:"
    echo "$OUTDIR"
    rm -rf "$OUTDIR"
fi

mkdir -p "$OUTDIR"

# ------------------------------------------------------------
# Node-local temporary directory
# ------------------------------------------------------------

rm -rf "$LOCAL_TMP"
mkdir -p "$LOCAL_TMP"
chmod 700 "$LOCAL_TMP"

cleanup() {
    echo
    echo "Cleaning local tmp:"
    echo "$LOCAL_TMP"
    rm -rf "$LOCAL_TMP"
}

trap cleanup EXIT

echo
echo "===== protein count ====="
grep -c '^>' "$IN"

echo
echo "===== local filesystem ====="
df -hT /tmp

echo
echo "===== shared filesystem ====="
df -hT "$STAGE_DIR"

# ------------------------------------------------------------
# DIAMOND-only eggNOG search
# ------------------------------------------------------------

CMD=(
    emapper.py
    -i "$IN"
    --itype proteins
    -m diamond
    --no_annot
    --data_dir "$DATA"
    --cpu "$SLURM_CPUS_PER_TASK"
    --temp_dir "$LOCAL_TMP"
    -o "$BASE_NAME"
    --output_dir "$OUTDIR"
)

echo
echo "============================================================"
echo "Starting Stage 1"
echo "Time: $(date)"
echo "Command:"
printf ' %q' "${CMD[@]}"
echo
echo "============================================================"

TIMELOG="${OUTDIR}/${BASE_NAME}.time.log"

/usr/bin/time \
    -v \
    -o "$TIMELOG" \
    "${CMD[@]}"

# ------------------------------------------------------------
# Validate Stage 1 outputs
# ------------------------------------------------------------

HITS="${OUTDIR}/${BASE_NAME}.emapper.hits"
SEED="${OUTDIR}/${BASE_NAME}.emapper.seed_orthologs"

echo
echo "===== output validation ====="

if [[ ! -s "$HITS" ]]; then
    echo "ERROR: hits missing or empty:"
    echo "$HITS"
    exit 1
fi

if [[ ! -s "$SEED" ]]; then
    echo "ERROR: seed orthologs missing or empty:"
    echo "$SEED"
    exit 1
fi

ls -lh "$HITS"
ls -lh "$SEED"

touch "$DONE"

echo
echo "===== timing ====="
cat "$TIMELOG"

echo
echo "============================================================"
echo "STAGE 1 COMPLETED SUCCESSFULLY"
echo "Chunk  : $BASE_NAME"
echo "Node   : $(hostname)"
echo "Finish : $(date)"
echo "============================================================"
