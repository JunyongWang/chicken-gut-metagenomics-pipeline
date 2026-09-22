#!/bin/bash

#SBATCH --job-name=kraken_array
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=160G
#SBATCH --time=06:00:00
#SBATCH --array=1-60%6
#SBATCH --output=logs/kraken_%A_%a.out
#SBATCH --error=logs/kraken_%A_%a.err

# ============================================================
# Environment
# ============================================================

: "${PROJECT_ROOT:?Set PROJECT_ROOT to the repository checkout}"
: "${KRAKEN_DB:?Set KRAKEN_DB to the standard_20260626 database directory}"
: "${CONDA_SH:?Set CONDA_SH to the conda shell initialization script}"

CONDA_ENV="${CONDA_ENV:-metagenomics}"
WORK_ROOT="${WORK_ROOT:-$PROJECT_ROOT/work}"
STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
DEHOST_ROOT="${DEHOST_ROOT:-$WORK_ROOT/02_dehost}"
SAMPLE_LIST="${SAMPLE_LIST:-$PROJECT_ROOT/config/samples.txt}"

source "$CONDA_SH"
conda activate "$CONDA_ENV"

set -euo pipefail

# Inputs, outputs, and logs are rooted at the configured stage directory.
cd "$STAGE_DIR"

# ============================================================
# Sample
# ============================================================

SAMPLE=$(
    sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST" \
    | tr -d '\r'
)

if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: no sample found for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

# ============================================================
# Paths
# ============================================================

DEHOST_DIR="$DEHOST_ROOT/$SAMPLE"

R1="$DEHOST_DIR/${SAMPLE}_R1.dehost.fq.gz"
R2="$DEHOST_DIR/${SAMPLE}_R2.dehost.fq.gz"

DB="$KRAKEN_DB"

OUTDIR="$STAGE_DIR/$SAMPLE"

mkdir -p "$OUTDIR"

# ============================================================
# Kraken2 output
# ============================================================

REPORT="$OUTDIR/${SAMPLE}.kraken.report"
KOUT="$OUTDIR/${SAMPLE}.kraken.output"
KOUT_GZ="${KOUT}.gz"
KLOG="$OUTDIR/${SAMPLE}.kraken.log"

DONE="$OUTDIR/.kraken_bracken.done"

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
# Input checks
# ============================================================

[[ -s "$R1" ]] || {
    echo "ERROR: missing R1:"
    echo "$R1"
    exit 1
}

[[ -s "$R2" ]] || {
    echo "ERROR: missing R2:"
    echo "$R2"
    exit 1
}

[[ -s "$DB/hash.k2d" ]] || {
    echo "ERROR: missing Kraken2 database file:"
    echo "$DB/hash.k2d"
    exit 1
}

[[ -s "$DB/opts.k2d" ]] || {
    echo "ERROR: missing Kraken2 database file:"
    echo "$DB/opts.k2d"
    exit 1
}

[[ -s "$DB/taxo.k2d" ]] || {
    echo "ERROR: missing Kraken2 database file:"
    echo "$DB/taxo.k2d"
    exit 1
}

[[ -s "$DB/database150mers.kmer_distrib" ]] || {
    echo "ERROR: missing Bracken 150-mer database:"
    echo "$DB/database150mers.kmer_distrib"
    exit 1
}

# ============================================================
# Clean incomplete files from previous failed runs
#
# This section runs only when .kraken_bracken.done is absent,
# so completed samples are not deleted.
# ============================================================

rm -f \
    "$REPORT" \
    "$KOUT" \
    "$KOUT_GZ" \
    "$KLOG"

for LEVEL in P C O F G S
do
    rm -f \
        "$OUTDIR/${SAMPLE}.${LEVEL}.bracken" \
        "$OUTDIR/${SAMPLE}.${LEVEL}.bracken.log"
done

# Bracken 会额外生成不同分类等级的 Kraken-style report
rm -f "$OUTDIR"/"${SAMPLE}".kraken_bracken_*.report

# ============================================================
# Job information
# ============================================================

echo "========================================"
echo "Kraken2 + Bracken START"
echo "========================================"
echo "Sample      : $SAMPLE"
echo "Array task  : $SLURM_ARRAY_TASK_ID"
echo "Job ID      : $SLURM_JOB_ID"
echo "Node        : $(hostname)"
echo "Threads     : $SLURM_CPUS_PER_TASK"
echo "Database    : $DB"
echo "R1          : $R1"
echo "R2          : $R2"
echo "Start       : $(date)"
echo "========================================"

echo
echo "Kraken2:"
kraken2 --version

echo
echo "===== Kraken2 START ====="
date

# ============================================================
# Kraken2
#
# Verified production settings:
#
# database   = Standard 20260626
# paired-end = yes
# gzip       = yes
# confidence = 0
# use-names  = yes
# ============================================================

kraken2 \
    --db "$DB" \
    --paired \
    --gzip-compressed \
    --threads "$SLURM_CPUS_PER_TASK" \
    --confidence 0 \
    --use-names \
    --report "$REPORT" \
    --output "$KOUT" \
    "$R1" "$R2" \
    2> "$KLOG"

# ============================================================
# Kraken2 validation
# ============================================================

[[ -s "$REPORT" ]] || {
    echo "ERROR: Kraken2 report missing or empty:"
    echo "$REPORT"
    exit 1
}

[[ -s "$KOUT" ]] || {
    echo "ERROR: Kraken2 per-read output missing or empty:"
    echo "$KOUT"
    exit 1
}

echo
echo "===== Kraken2 FINISHED ====="
date

echo
echo "===== Kraken2 classification summary ====="
cat "$KLOG"

# ============================================================
# Bracken
#
# Verified production settings:
#
# read length = 150
# threshold   = 10
#
# P = Phylum
# C = Class
# O = Order
# F = Family
# G = Genus
# S = Species
# ============================================================

for LEVEL in P C O F G S
do

    BOUT="$OUTDIR/${SAMPLE}.${LEVEL}.bracken"
    BLOG="$OUTDIR/${SAMPLE}.${LEVEL}.bracken.log"

    echo
    echo "========================================"
    echo "Bracken level $LEVEL START"
    echo "========================================"
    date

    bracken \
        -d "$DB" \
        -i "$REPORT" \
        -o "$BOUT" \
        -r 150 \
        -l "$LEVEL" \
        -t 10 \
        > "$BLOG" 2>&1

    [[ -s "$BOUT" ]] || {
        echo "ERROR: Bracken $LEVEL output missing or empty:"
        echo "$BOUT"
        echo
        echo "Bracken log:"
        cat "$BLOG" || true
        exit 1
    }

    echo "Bracken level $LEVEL FINISHED"
    date

done

# ============================================================
# Compress large Kraken2 per-read output
# ============================================================

echo
echo "========================================"
echo "Compressing Kraken2 per-read output"
echo "========================================"

pigz -p 8 "$KOUT"

[[ -s "$KOUT_GZ" ]] || {
    echo "ERROR: compressed Kraken2 output missing"
    exit 1
}

# Validate gzip integrity.
gzip -t "$KOUT_GZ"

# ============================================================
# Final validation
# ============================================================

[[ -s "$REPORT" ]] || {
    echo "ERROR: final Kraken report check failed"
    exit 1
}

[[ -s "$KOUT_GZ" ]] || {
    echo "ERROR: final Kraken output check failed"
    exit 1
}

for LEVEL in P C O F G S
do

    [[ -s "$OUTDIR/${SAMPLE}.${LEVEL}.bracken" ]] || {
        echo "ERROR: final Bracken check failed for level $LEVEL"
        exit 1
    }

done

# ============================================================
# Completion marker
#
# Create this file only after Kraken2, all six Bracken levels,
# and the gzip integrity check succeed.
# ============================================================

touch "$DONE"

echo
echo "========================================"
echo "Kraken2 + Bracken FINISHED"
echo "========================================"
echo "Sample : $SAMPLE"
echo "Node   : $(hostname)"
echo "Finish : $(date)"
echo "========================================"

echo
echo "Output files:"
ls -lh "$OUTDIR"
