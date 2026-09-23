#!/bin/bash
#SBATCH --job-name=eggnog_NR
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=24:00:00
#SBATCH --output=logs/eggnog_NR_%A_%a.out
#SBATCH --error=logs/eggnog_NR_%A_%a.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/12_function}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
EGGNOG_ENV="${EGGNOG_ENV:-eggnog}"
EGGNOG_DATA="${EGGNOG_DATA:?Set EGGNOG_DATA to the eggNOG-mapper 5.0.2 data directory}"
NR_CHUNKS_FILE="${NR_CHUNKS_FILE:-$STAGE_DIR/eggnog/11A/chunks.txt}"

cd "$STAGE_DIR"
source "$CONDA_SH"
conda activate "$EGGNOG_ENV"

DATA="$EGGNOG_DATA"

CHUNK=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$NR_CHUNKS_FILE")

if [[ -z "$CHUNK" ]]; then
    echo "ERROR: cannot determine chunk"
    exit 1
fi

BASE="${CHUNK%.faa}"

IN="$STAGE_DIR/eggnog/11A/chunks/$CHUNK"
OUTDIR="$STAGE_DIR/eggnog/11A/results/$BASE"

ANN="$OUTDIR/${BASE}.emapper.annotations"
HITS="$OUTDIR/${BASE}.emapper.hits"
SEED="$OUTDIR/${BASE}.emapper.seed_orthologs"

QC="$OUTDIR/${BASE}.qc.tsv"
DONE="$OUTDIR/.eggnog.done"

mkdir -p "$OUTDIR"

echo "============================================================"
echo "eggNOG NR formal annotation"
echo "Chunk : $CHUNK"
echo "Node  : $(hostname)"
echo "CPU   : $SLURM_CPUS_PER_TASK"
echo "Start : $(date)"
echo "============================================================"

# 已完整完成则直接跳过
if [[ -f "$DONE" && -s "$ANN" && -s "$HITS" && -s "$SEED" ]]; then
    echo "$BASE already complete, skip."
    exit 0
fi

[[ -s "$IN" ]] || {
    echo "ERROR: missing input $IN"
    exit 1
}

# ------------------------------------------------------------
# 自动判断是否属于中断续跑
# 不删除任何已有 eggNOG 中间结果
# ------------------------------------------------------------

RESUME=0

if [[ -e "$HITS" || -e "$ANN" || -e "$SEED" ]]; then
    RESUME=1
fi

echo "Resume mode : $RESUME"

if [[ "$RESUME" -eq 1 ]]; then

    /usr/bin/time -v \
        -o "$OUTDIR/${BASE}.time.log" \
        emapper.py \
            -i "$IN" \
            --itype proteins \
            -m diamond \
            --data_dir "$DATA" \
            --cpu "$SLURM_CPUS_PER_TASK" \
            -o "$BASE" \
            --output_dir "$OUTDIR" \
            --resume

else

    /usr/bin/time -v \
        -o "$OUTDIR/${BASE}.time.log" \
        emapper.py \
            -i "$IN" \
            --itype proteins \
            -m diamond \
            --data_dir "$DATA" \
            --cpu "$SLURM_CPUS_PER_TASK" \
            -o "$BASE" \
            --output_dir "$OUTDIR"

fi

# ------------------------------------------------------------
# Final QC
# ------------------------------------------------------------

[[ -s "$ANN" ]] || {
    echo "ERROR: annotations missing"
    exit 1
}

[[ -s "$HITS" ]] || {
    echo "ERROR: hits missing"
    exit 1
}

[[ -s "$SEED" ]] || {
    echo "ERROR: seed orthologs missing"
    exit 1
}

INPUT_N=$(grep -c '^>' "$IN")

ANNOTATED_N=$(
    grep -v '^#' "$ANN" |
    awk 'NF>0' |
    wc -l
)

SEED_N=$(
    grep -v '^#' "$SEED" |
    awk 'NF>0' |
    wc -l
)

printf \
"Chunk\tInput_proteins\tAnnotated\tSeed_orthologs\tAnnotation_rate_percent\n" \
> "$QC"

awk \
    -v c="$BASE" \
    -v n="$INPUT_N" \
    -v a="$ANNOTATED_N" \
    -v s="$SEED_N" \
    'BEGIN {
        printf "%s\t%d\t%d\t%d\t%.4f\n",
               c,n,a,s,100*a/n
    }' >> "$QC"

touch "$DONE"

echo
echo "===== QC ====="
cat "$QC"

echo
echo "Finish : $(date)"
echo "============================================================"

