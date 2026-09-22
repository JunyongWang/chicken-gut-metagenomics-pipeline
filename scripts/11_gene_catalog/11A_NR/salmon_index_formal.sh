#!/bin/bash
#SBATCH --job-name=salmon_index
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=200G
#SBATCH --time=12:00:00
#SBATCH --output=logs/salmon_index_%j.out
#SBATCH --error=logs/salmon_index_%j.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/11_gene_catalog/11A_NR}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate gene_catalog

REF="$STAGE_DIR/nr/NR_gene_catalog.ffn"

OUTDIR="$STAGE_DIR/salmon"
INDEX="$OUTDIR/NR_gene_index"
TMP_INDEX="$OUTDIR/NR_gene_index.tmp"

LOG="$OUTDIR/salmon_index.log"
TIMELOG="$OUTDIR/salmon_index.time.log"
DONE="$OUTDIR/.salmon_index.done"

EXPECTED=13151701

mkdir -p "$OUTDIR"

echo "============================================================"
echo "Salmon formal index"
echo "============================================================"
echo "Node      : $(hostname)"
echo "CPUs      : $SLURM_CPUS_PER_TASK"
echo "Memory    : 200G"
echo "Reference : $REF"
echo "Expected  : $EXPECTED genes"
echo "k-mer     : 31"
echo "Start     : $(date)"
echo "============================================================"

# ------------------------------------------------------------
# 1. checkpoint
# ------------------------------------------------------------

if [[ -f "$DONE" && -d "$INDEX" && -s "$INDEX/info.json" ]]; then
    echo "Salmon index already complete, skip."
    exit 0
fi

# ------------------------------------------------------------
# 2. input check
# ------------------------------------------------------------

if [[ ! -s "$REF" ]]; then
    echo "ERROR: missing reference: $REF"
    exit 1
fi

N=$(grep -c '^>' "$REF")

echo
echo "Reference genes : $N"

if [[ "$N" -ne "$EXPECTED" ]]; then
    echo "ERROR: expected $EXPECTED genes, got $N"
    exit 1
fi

# ------------------------------------------------------------
# 3. clean incomplete previous run
# ------------------------------------------------------------

rm -rf "$TMP_INDEX"
rm -f "$DONE"

# ------------------------------------------------------------
# 4. build Salmon index
# ------------------------------------------------------------

echo
echo "Building Salmon index..."
echo

/usr/bin/time -v \
    -o "$TIMELOG" \
    salmon index \
        -t "$REF" \
        -i "$TMP_INDEX" \
        -k 31 \
        -p "$SLURM_CPUS_PER_TASK" \
        --keepDuplicates \
        --no-clip \
        > "$LOG" 2>&1

# ------------------------------------------------------------
# 5. index QC
# ------------------------------------------------------------

if [[ ! -d "$TMP_INDEX" ]]; then
    echo "ERROR: index directory missing"
    exit 1
fi

if [[ ! -s "$TMP_INDEX/info.json" ]]; then
    echo "ERROR: info.json missing"
    exit 1
fi

if [[ ! -s "$TMP_INDEX/index.ssi" ]]; then
    echo "ERROR: index.ssi missing"
    exit 1
fi

if [[ ! -s "$TMP_INDEX/index.refinfo" ]]; then
    echo "ERROR: index.refinfo missing"
    exit 1
fi

# ------------------------------------------------------------
# 6. finalize
# ------------------------------------------------------------

rm -rf "$INDEX"
mv "$TMP_INDEX" "$INDEX"

touch "$DONE"

# ------------------------------------------------------------
# 7. final report
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Salmon index completed"
echo "============================================================"

echo
echo "Index size:"
du -sh "$INDEX"

echo
echo "Index files:"
ls -lh "$INDEX"

echo
echo "Done marker:"
ls -lh "$DONE"

echo
echo "Finish : $(date)"
echo "============================================================"
