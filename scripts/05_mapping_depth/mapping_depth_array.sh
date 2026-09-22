#!/bin/bash

#SBATCH --job-name=mapdepth_array
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=12G
#SBATCH --time=04:00:00
#SBATCH --array=1-60%10
#SBATCH --output=logs/mapdepth_%A_%a.out
#SBATCH --error=logs/mapdepth_%A_%a.err


# ============================================================
# Environment
# ============================================================

: "${PROJECT_ROOT:?Set PROJECT_ROOT to the repository checkout}"
: "${CONDA_SH:?Set CONDA_SH to the conda shell initialization script}"

CONDA_ENV="${CONDA_ENV:-metagenomics}"
WORK_ROOT="${WORK_ROOT:-$PROJECT_ROOT/work}"
STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
DEHOST_ROOT="${DEHOST_ROOT:-$WORK_ROOT/02_dehost}"
ASSEMBLY_ROOT="${ASSEMBLY_ROOT:-$WORK_ROOT/04_assembly}"
SAMPLE_LIST="${SAMPLE_LIST:-$PROJECT_ROOT/config/samples.txt}"

source "$CONDA_SH"
conda activate "$CONDA_ENV"

set -euo pipefail

cd "$STAGE_DIR"


# ============================================================
# Sample
# ============================================================

SAMPLE=$(
    sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST" \
    | tr -d '\r'
)

if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: no sample for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi


# ============================================================
# Input
# ============================================================

DEHOST_DIR="$DEHOST_ROOT/$SAMPLE"

ASSEMBLY_DIR="$ASSEMBLY_ROOT/$SAMPLE"

R1="$DEHOST_DIR/${SAMPLE}_R1.dehost.fq.gz"
R2="$DEHOST_DIR/${SAMPLE}_R2.dehost.fq.gz"

CONTIGS="$ASSEMBLY_DIR/${SAMPLE}.final.contigs.fa"


# ============================================================
# Output
# ============================================================

SAMPLE_DIR="$STAGE_DIR/$SAMPLE"

INDEX_DIR="$SAMPLE_DIR/bowtie2_index"

INDEX="$INDEX_DIR/${SAMPLE}.contigs"

BAM="$SAMPLE_DIR/${SAMPLE}.contigs.sorted.bam"
BAI="${BAM}.bai"

MAPLOG="$SAMPLE_DIR/${SAMPLE}.bowtie2.log"

FLAGSTAT="$SAMPLE_DIR/${SAMPLE}.flagstat.txt"

DEPTH="$SAMPLE_DIR/${SAMPLE}.contig_depth.tsv"
DEPTHLOG="$SAMPLE_DIR/${SAMPLE}.depth.log"

TIMELOG="$SAMPLE_DIR/${SAMPLE}.mapping.time.log"

TMP_PREFIX="$SAMPLE_DIR/${SAMPLE}.sorttmp"

DONE="$SAMPLE_DIR/.mapping_depth.done"

mkdir -p "$SAMPLE_DIR"


# ============================================================
# Skip completed sample
# ============================================================

if [[ -f "$DONE" ]]; then

    echo "========================================"
    echo "Sample already completed: $SAMPLE"
    echo "Skip."
    echo "========================================"

    exit 0

fi


# ============================================================
# Checks
# ============================================================

[[ -s "$R1" ]] || {
    echo "ERROR: missing R1: $R1"
    exit 1
}

[[ -s "$R2" ]] || {
    echo "ERROR: missing R2: $R2"
    exit 1
}

[[ -s "$CONTIGS" ]] || {
    echo "ERROR: missing contigs: $CONTIGS"
    exit 1
}

command -v bowtie2 >/dev/null 2>&1 || {
    echo "ERROR: bowtie2 not found"
    exit 1
}

command -v bowtie2-build >/dev/null 2>&1 || {
    echo "ERROR: bowtie2-build not found"
    exit 1
}

command -v samtools >/dev/null 2>&1 || {
    echo "ERROR: samtools not found"
    exit 1
}

command -v jgi_summarize_bam_contig_depths >/dev/null 2>&1 || {
    echo "ERROR: jgi_summarize_bam_contig_depths not found"
    exit 1
}


# ============================================================
# Clean incomplete previous run
# ============================================================

rm -f \
    "$BAM" \
    "$BAI" \
    "$MAPLOG" \
    "$FLAGSTAT" \
    "$DEPTH" \
    "$DEPTHLOG" \
    "$TIMELOG"

rm -f "${TMP_PREFIX}"*

rm -rf "$INDEX_DIR"

mkdir -p "$INDEX_DIR"


# ============================================================
# Information
# ============================================================

echo "========================================"
echo "MAPPING + DEPTH START"
echo "========================================"
echo "Sample       : $SAMPLE"
echo "Array task   : $SLURM_ARRAY_TASK_ID"
echo "Job ID       : $SLURM_JOB_ID"
echo "Node         : $(hostname)"
echo "CPUs         : $SLURM_CPUS_PER_TASK"
echo "R1           : $R1"
echo "R2           : $R2"
echo "Contigs      : $CONTIGS"
echo "Start        : $(date)"
echo "========================================"


# ============================================================
# Step 1: Bowtie2 index
# ============================================================

echo
echo "===== Bowtie2 index START ====="
date

bowtie2-build \
    --threads "$SLURM_CPUS_PER_TASK" \
    "$CONTIGS" \
    "$INDEX"

echo "===== Bowtie2 index FINISHED ====="
date


# ============================================================
# Step 2: Mapping + coordinate sort
#
# Bowtie2       = 6 threads
# samtools sort = main thread + 1 extra thread
#
# Total ≈ 8 CPUs
#
# No intermediate SAM file.
# ============================================================

echo
echo "===== Mapping START ====="
date

/usr/bin/time -v \
    -o "$TIMELOG" \
    bash -c '
        set -o pipefail

        bowtie2 \
            --end-to-end \
            --sensitive \
            -x "$1" \
            -1 "$2" \
            -2 "$3" \
            -p 6 \
            2> "$4" \
        | samtools sort \
            -@ 1 \
            -m 1G \
            -T "$5" \
            -o "$6" \
            -
    ' _ \
    "$INDEX" \
    "$R1" \
    "$R2" \
    "$MAPLOG" \
    "$TMP_PREFIX" \
    "$BAM"

echo "===== Mapping FINISHED ====="
date


# ============================================================
# Step 3: BAM validation
# ============================================================

[[ -s "$BAM" ]] || {
    echo "ERROR: BAM missing"
    exit 1
}

samtools quickcheck -v "$BAM"


# ============================================================
# Step 4: BAM index
# ============================================================

samtools index \
    -@ 7 \
    "$BAM"

[[ -s "$BAI" ]] || {
    echo "ERROR: BAM index missing"
    exit 1
}


# ============================================================
# Step 5: Mapping QC
# ============================================================

samtools flagstat \
    -@ 7 \
    "$BAM" \
    > "$FLAGSTAT"

[[ -s "$FLAGSTAT" ]] || {
    echo "ERROR: flagstat missing"
    exit 1
}


# ============================================================
# Step 6: MetaBAT2-compatible contig depth
#
# Keep mother depth table:
# no contig length filtering here.
#
# 97% end-to-end identity used for depth calculation.
# ============================================================

jgi_summarize_bam_contig_depths \
    --outputDepth "$DEPTH" \
    --percentIdentity 97 \
    --referenceFasta "$CONTIGS" \
    "$BAM" \
    > "$DEPTHLOG" 2>&1

[[ -s "$DEPTH" ]] || {
    echo "ERROR: depth table missing"
    exit 1
}


# ============================================================
# Check depth row count
# ============================================================

CONTIG_NUM=$(grep -c '^>' "$CONTIGS")

DEPTH_NUM=$(
    awk 'END{print NR-1}' "$DEPTH"
)

echo
echo "Assembly contigs : $CONTIG_NUM"
echo "Depth rows       : $DEPTH_NUM"

if [[ "$CONTIG_NUM" -ne "$DEPTH_NUM" ]]; then

    echo "ERROR: depth row count does not match assembly contig count"

    exit 1

fi


# ============================================================
# Remove temporary files
# ============================================================

rm -f "${TMP_PREFIX}"*


# ============================================================
# Remove Bowtie2 index after successful depth generation
#
# The original contigs are retained, so the index can always
# be rebuilt later if necessary.
# ============================================================

rm -rf "$INDEX_DIR"


# ============================================================
# Completion marker
# ============================================================

touch "$DONE"


# ============================================================
# Final report
# ============================================================

echo
echo "========================================"
echo "MAPPING + DEPTH FINISHED"
echo "========================================"
echo "Sample : $SAMPLE"
echo "Node   : $(hostname)"
echo "Finish : $(date)"
echo "========================================"

echo
echo "===== Bowtie2 summary ====="
cat "$MAPLOG"

echo
echo "===== Flagstat ====="
cat "$FLAGSTAT"

echo
echo "===== Depth ====="
wc -l "$DEPTH"
head -n 3 "$DEPTH"

echo
echo "===== Resource ====="
cat "$TIMELOG"

echo
echo "===== Output ====="
ls -lh "$SAMPLE_DIR"
