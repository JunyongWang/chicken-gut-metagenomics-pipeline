#!/bin/bash

#SBATCH --job-name=fastp
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=logs/fastp_%A_%a.out
#SBATCH --error=logs/fastp_%A_%a.err

# ============================================================
# Conda
# ============================================================

: "${PROJECT_ROOT:?Set PROJECT_ROOT to the repository checkout}"
: "${RAW_DIR:?Set RAW_DIR to the directory containing raw paired FASTQ files}"
: "${CONDA_SH:?Set CONDA_SH to the conda shell initialization script}"

CONDA_ENV="${CONDA_ENV:-metagenomics}"
STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
SAMPLE_LIST="${SAMPLE_LIST:-$PROJECT_ROOT/config/samples.txt}"

source "$CONDA_SH"
conda activate "$CONDA_ENV"

set -euo pipefail

# ============================================================
# Paths
# ============================================================

WORK="$STAGE_DIR"

# ============================================================
# Get sample name
# ============================================================

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: no sample for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

R1="$RAW_DIR/${SAMPLE}_R1.fq.gz"
R2="$RAW_DIR/${SAMPLE}_R2.fq.gz"

OUTDIR="$WORK/$SAMPLE"

mkdir -p "$OUTDIR"

OUT_R1="$OUTDIR/${SAMPLE}_R1.clean.fq.gz"
OUT_R2="$OUTDIR/${SAMPLE}_R2.clean.fq.gz"

HTML="$OUTDIR/${SAMPLE}.fastp.html"
JSON="$OUTDIR/${SAMPLE}.fastp.json"

# ============================================================
# Input check
# ============================================================

if [[ ! -s "$R1" ]]; then
    echo "ERROR: missing R1: $R1"
    exit 1
fi

if [[ ! -s "$R2" ]]; then
    echo "ERROR: missing R2: $R2"
    exit 1
fi

# ============================================================
# Job information
# ============================================================

echo "========================================"
echo "fastp START"
echo "========================================"
echo "Sample    : $SAMPLE"
echo "Array ID  : $SLURM_ARRAY_TASK_ID"
echo "Job ID    : $SLURM_JOB_ID"
echo "Node      : $(hostname)"
echo "Threads   : $SLURM_CPUS_PER_TASK"
echo "R1        : $R1"
echo "R2        : $R2"
echo "Start     : $(date)"
echo "========================================"

fastp --version

# ============================================================
# fastp QC
#
# Adapter: automatic PE detection
# Quality trimming: 4-bp window, mean Q20
# Minimum length: 50 bp
# Low-complexity threshold: 30
# ============================================================

fastp \
    --in1 "$R1" \
    --in2 "$R2" \
    --out1 "$OUT_R1" \
    --out2 "$OUT_R2" \
    --detect_adapter_for_pe \
    --cut_front \
    --cut_right \
    --cut_window_size 4 \
    --cut_mean_quality 20 \
    --length_required 50 \
    --low_complexity_filter \
    --complexity_threshold 30 \
    --thread "$SLURM_CPUS_PER_TASK" \
    --html "$HTML" \
    --json "$JSON"

# ============================================================
# Output integrity check
# ============================================================

gzip -t "$OUT_R1"
gzip -t "$OUT_R2"

if [[ ! -s "$HTML" ]]; then
    echo "ERROR: HTML report missing"
    exit 1
fi

if [[ ! -s "$JSON" ]]; then
    echo "ERROR: JSON report missing"
    exit 1
fi

touch "$OUTDIR/.fastp.done"

echo
echo "========================================"
echo "fastp FINISHED"
echo "========================================"
echo "Sample : $SAMPLE"
echo "Finish : $(date)"
echo
ls -lh "$OUTDIR"
echo "========================================"
