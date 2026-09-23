#!/bin/bash
#SBATCH --job-name=eggnog_S2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64G
#SBATCH --time=06:00:00
#SBATCH --output=logs/eggnog_S2_%A_%a.out
#SBATCH --error=logs/eggnog_S2_%A_%a.err

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

BATCH=$(printf "%02d" "$SLURM_ARRAY_TASK_ID")

MANIFEST="${BASE}/eggnog/11A/stage2_annotation/manifests/batch_${BATCH}.txt"
OUTBASE="${BASE}/eggnog/11A/stage2_annotation/formal"
OUTDIR="${OUTBASE}/batch_${BATCH}"

PREFIX="batch_${BATCH}"
MERGED="${OUTDIR}/${PREFIX}.seed_orthologs"
ANN="${OUTDIR}/${PREFIX}.emapper.annotations"
DONE="${OUTDIR}/.annotation.done"

LOCAL_TMP="${TMPDIR:-/tmp}/${USER:-user}/eggnog_S2_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"

echo "============================================================"
echo "eggNOG Stage 2 formal"
echo "Batch     : ${BATCH}"
echo "Node      : $(hostname)"
echo "CPU       : ${SLURM_CPUS_PER_TASK}"
echo "Memory    : 64G"
echo "Manifest  : ${MANIFEST}"
echo "Start     : $(date)"
echo "============================================================"

[[ -s "$MANIFEST" ]] || {
    echo "ERROR: manifest missing"
    exit 1
}

[[ -s "${DATA}/eggnog.db" ]] || {
    echo "ERROR: eggnog.db missing"
    exit 1
}

[[ -s "${DATA}/eggnog.taxa.db" ]] || {
    echo "ERROR: eggnog.taxa.db missing"
    exit 1
}

[[ -e "${DATA}/.copy_complete" ]] || {
    echo "ERROR: database copy-complete marker missing"
    exit 1
}

NCHUNK=$(wc -l < "$MANIFEST")

[[ "$NCHUNK" -eq 10 ]] || {
    echo "ERROR: expected 10 chunks, found $NCHUNK"
    exit 1
}

if [[ -e "$DONE" && -s "$ANN" ]]; then
    echo "Batch ${BATCH} already complete. Skip."
    exit 0
fi

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

rm -rf "$LOCAL_TMP"
mkdir -p "$LOCAL_TMP"
chmod 700 "$LOCAL_TMP"

export TMPDIR="$LOCAL_TMP"

cleanup() {
    rm -rf "$LOCAL_TMP"
}
trap cleanup EXIT

echo
echo "===== chunks ====="
cat "$MANIFEST"

FIRST=1
EXPECTED_ROWS=0

while read -r CHUNK
do
    SEED="${BASE}/eggnog/11A/stage1_search/${CHUNK}/${CHUNK}.emapper.seed_orthologs"

    [[ -s "$SEED" ]] || {
        echo "ERROR: missing seed: $SEED"
        exit 1
    }

    N=$(awk '!/^#/ {n++} END{print n+0}' "$SEED")
    EXPECTED_ROWS=$((EXPECTED_ROWS + N))

    if [[ "$FIRST" -eq 1 ]]; then
        cat "$SEED" > "$MERGED"
        FIRST=0
    else
        awk '!/^#/' "$SEED" >> "$MERGED"
    fi

done < "$MANIFEST"

MERGED_ROWS=$(awk '!/^#/ {n++} END{print n+0}' "$MERGED")

UNIQUE_IDS=$(
    awk -F'\t' '!/^#/ {print $1}' "$MERGED" \
    | LC_ALL=C sort -u -T "$LOCAL_TMP" \
    | wc -l
)

echo
echo "Expected seed rows : $EXPECTED_ROWS"
echo "Merged seed rows   : $MERGED_ROWS"
echo "Unique query IDs   : $UNIQUE_IDS"

[[ "$EXPECTED_ROWS" -eq "$MERGED_ROWS" ]] || {
    echo "ERROR: seed row mismatch"
    exit 1
}

[[ "$MERGED_ROWS" -eq "$UNIQUE_IDS" ]] || {
    echo "ERROR: duplicate query IDs"
    exit 1
}

CMD=(
    emapper.py
    -m no_search
    --annotate_hits_table "$MERGED"
    --data_dir "$DATA"
    --dbmem
    --cpu "$SLURM_CPUS_PER_TASK"
    -o "$PREFIX"
    --output_dir "$OUTDIR"
)

echo
echo "===== command ====="
printf ' %q' "${CMD[@]}"
echo

/usr/bin/time \
    -v \
    -o "${OUTDIR}/${PREFIX}.time.log" \
    "${CMD[@]}"

[[ -s "$ANN" ]] || {
    echo "ERROR: annotation output missing"
    exit 1
}

ANN_ROWS=$(awk '!/^#/ {n++} END{print n+0}' "$ANN")

ANN_UNIQUE=$(
    awk -F'\t' '!/^#/ {print $1}' "$ANN" \
    | LC_ALL=C sort -u -T "$LOCAL_TMP" \
    | wc -l
)

echo
echo "Annotation rows    : $ANN_ROWS"
echo "Unique annotations : $ANN_UNIQUE"

[[ "$ANN_ROWS" -eq "$ANN_UNIQUE" ]] || {
    echo "ERROR: duplicate annotation query IDs"
    exit 1
}

[[ "$ANN_ROWS" -le "$MERGED_ROWS" ]] || {
    echo "ERROR: annotations exceed seed queries"
    exit 1
}

{
    printf 'metric\tvalue\n'
    printf 'batch\t%s\n' "$BATCH"
    printf 'chunks\t%s\n' "$NCHUNK"
    printf 'seed_rows\t%s\n' "$MERGED_ROWS"
    printf 'annotation_rows\t%s\n' "$ANN_ROWS"
} > "${OUTDIR}/${PREFIX}.summary.tsv"

touch "$DONE"

echo
echo "===== timing ====="
cat "${OUTDIR}/${PREFIX}.time.log"

echo
echo "============================================================"
echo "STAGE 2 BATCH ${BATCH} COMPLETED"
echo "Finish: $(date)"
echo "============================================================"
