#!/bin/bash

#SBATCH --job-name=dehost
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=06:00:00
#SBATCH --output=logs/dehost_%A_%a.out
#SBATCH --error=logs/dehost_%A_%a.err

: "${PROJECT_ROOT:?Set PROJECT_ROOT to the repository checkout}"
: "${HOST_INDEX:?Set HOST_INDEX to the Bowtie2 chicken GRCg7b index prefix}"
: "${CONDA_SH:?Set CONDA_SH to the conda shell initialization script}"

CONDA_ENV="${CONDA_ENV:-metagenomics}"
WORK_ROOT="${WORK_ROOT:-$PROJECT_ROOT/work}"
STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
FASTP_DIR="${FASTP_DIR:-$WORK_ROOT/01_fastp}"
SAMPLE_LIST="${SAMPLE_LIST:-$PROJECT_ROOT/config/samples.txt}"

source "$CONDA_SH"
conda activate "$CONDA_ENV"

set -euo pipefail

WORK="$STAGE_DIR"

# ============================================================
# Sample
# ============================================================

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: no sample for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

R1="$FASTP_DIR/$SAMPLE/${SAMPLE}_R1.clean.fq.gz"
R2="$FASTP_DIR/$SAMPLE/${SAMPLE}_R2.clean.fq.gz"

OUTDIR="$WORK/$SAMPLE"
mkdir -p "$OUTDIR"

OUT_R1="$OUTDIR/${SAMPLE}_R1.dehost.fq.gz"
OUT_R2="$OUTDIR/${SAMPLE}_R2.dehost.fq.gz"

MAPLOG="$OUTDIR/${SAMPLE}.bowtie2.log"
FASTQLOG="$OUTDIR/${SAMPLE}.samtools_fastq.log"

# ============================================================
# Input check
# ============================================================

[[ -s "$R1" ]] || { echo "ERROR: missing $R1"; exit 1; }
[[ -s "$R2" ]] || { echo "ERROR: missing $R2"; exit 1; }

echo "========================================"
echo "Bowtie2 dehost START"
echo "========================================"
echo "Sample     : $SAMPLE"
echo "Array ID   : $SLURM_ARRAY_TASK_ID"
echo "Job ID     : $SLURM_JOB_ID"
echo "Node       : $(hostname)"
echo "Threads    : $SLURM_CPUS_PER_TASK"
echo "Host index : $HOST_INDEX"
echo "R1         : $R1"
echo "R2         : $R2"
echo "Start      : $(date)"
echo "========================================"

# ============================================================
# Bowtie2 mapping to chicken genome
#
# samtools view -f 12:
#   retain only read pairs where BOTH mates are unmapped
#
# This is a strict dehosting strategy:
# if either mate maps to chicken, the whole pair is discarded.
# ============================================================

bowtie2 \
    --very-sensitive \
    -x "$HOST_INDEX" \
    -1 "$R1" \
    -2 "$R2" \
    -p 12 \
    2> "$MAPLOG" \
| samtools view \
    -u \
    -f 12 \
    -F 256 \
    -@ 2 \
    - \
| samtools collate \
    -u \
    -O \
    -@ 2 \
    - \
| samtools fastq \
    -@ 2 \
    -1 "$OUT_R1" \
    -2 "$OUT_R2" \
    -0 /dev/null \
    -s /dev/null \
    -n \
    - \
    2> "$FASTQLOG"

# ============================================================
# Output checks
# ============================================================

gzip -t "$OUT_R1"
gzip -t "$OUT_R2"

[[ -s "$OUT_R1" ]] || { echo "ERROR: empty dehost R1"; exit 1; }
[[ -s "$OUT_R2" ]] || { echo "ERROR: empty dehost R2"; exit 1; }

touch "$OUTDIR/.dehost.done"

echo
echo "===== Bowtie2 summary ====="
cat "$MAPLOG"

echo
echo "===== samtools fastq summary ====="
cat "$FASTQLOG"

echo
echo "========================================"
echo "Bowtie2 dehost FINISHED"
echo "Sample : $SAMPLE"
echo "Finish : $(date)"
echo "========================================"

ls -lh "$OUTDIR"
