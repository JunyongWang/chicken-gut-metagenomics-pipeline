#!/bin/bash

#SBATCH --job-name=megahit_array
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=06:00:00
#SBATCH --array=1-60%9
#SBATCH --output=logs/megahit_%A_%a.out
#SBATCH --error=logs/megahit_%A_%a.err

# ============================================================
# Environment
# ============================================================

: "${PROJECT_ROOT:?Set PROJECT_ROOT to the repository checkout}"
: "${CONDA_SH:?Set CONDA_SH to the conda shell initialization script}"

CONDA_ENV="${CONDA_ENV:-metagenomics}"
WORK_ROOT="${WORK_ROOT:-$PROJECT_ROOT/work}"
STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
DEHOST_ROOT="${DEHOST_ROOT:-$WORK_ROOT/02_dehost}"
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

R1="$DEHOST_DIR/${SAMPLE}_R1.dehost.fq.gz"
R2="$DEHOST_DIR/${SAMPLE}_R2.dehost.fq.gz"

# ============================================================
# Output
# ============================================================

SAMPLE_DIR="$STAGE_DIR/$SAMPLE"
MEGAHIT_DIR="$SAMPLE_DIR/megahit"

RUNLOG="$SAMPLE_DIR/${SAMPLE}.megahit.log"
TIMELOG="$SAMPLE_DIR/${SAMPLE}.megahit.time.log"

STATS="$SAMPLE_DIR/${SAMPLE}.contig_stats.txt"
LENGTH_SUMMARY="$SAMPLE_DIR/${SAMPLE}.contig_length_summary.tsv"
NX_SUMMARY="$SAMPLE_DIR/${SAMPLE}.N50_N90.tsv"

DONE="$SAMPLE_DIR/.assembly.done"

mkdir -p "$SAMPLE_DIR"

# ============================================================
# Skip completed samples
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
    echo "ERROR: missing R1"
    echo "$R1"
    exit 1
}

[[ -s "$R2" ]] || {
    echo "ERROR: missing R2"
    echo "$R2"
    exit 1
}

command -v megahit >/dev/null 2>&1 || {
    echo "ERROR: megahit not found"
    exit 1
}

command -v seqkit >/dev/null 2>&1 || {
    echo "ERROR: seqkit not found"
    exit 1
}

command -v python >/dev/null 2>&1 || {
    echo "ERROR: python not found"
    exit 1
}

# ============================================================
# Clean files from an incomplete previous run
#
# Only executed when .assembly.done does NOT exist.
# Completed samples will never reach this section.
# ============================================================

rm -rf "$MEGAHIT_DIR"

rm -f \
    "$RUNLOG" \
    "$TIMELOG" \
    "$STATS" \
    "$LENGTH_SUMMARY" \
    "$NX_SUMMARY" \
    "$SAMPLE_DIR/${SAMPLE}.final.contigs.fa"

# ============================================================
# Job information
# ============================================================

echo "========================================"
echo "MEGAHIT assembly START"
echo "========================================"
echo "Sample       : $SAMPLE"
echo "Array task   : $SLURM_ARRAY_TASK_ID"
echo "Job ID       : $SLURM_JOB_ID"
echo "Node         : $(hostname)"
echo "Threads      : $SLURM_CPUS_PER_TASK"
echo "R1           : $R1"
echo "R2           : $R2"
echo "Start        : $(date)"
echo "========================================"

megahit --version

# ============================================================
# MEGAHIT
#
# Final assembly parameters:
#
# assembler       = MEGAHIT 1.2.9
# strategy        = individual assembly
# k-list          = 27,37,47,57,67,77,87
# kmin-1pass      = yes
# min-count       = 2
# min-contig-len  = 500 bp
#
# Computational resources:
#
# Slurm memory    = 32 GiB
# MEGAHIT -m      = 24,000,000,000 bytes (~22.4 GiB)
# threads         = 16
# ============================================================

echo
echo "===== MEGAHIT START ====="
date

/usr/bin/time -v \
    -o "$TIMELOG" \
    megahit \
        -1 "$R1" \
        -2 "$R2" \
        --kmin-1pass \
        --k-list 27,37,47,57,67,77,87 \
        --min-count 2 \
        --min-contig-len 500 \
        -t "$SLURM_CPUS_PER_TASK" \
        -m 24000000000 \
        -o "$MEGAHIT_DIR" \
        > "$RUNLOG" 2>&1

echo
echo "===== MEGAHIT FINISHED ====="
date

# ============================================================
# Check assembly
# ============================================================

CONTIGS="$MEGAHIT_DIR/final.contigs.fa"

[[ -s "$CONTIGS" ]] || {
    echo "ERROR: MEGAHIT final.contigs.fa missing"
    exit 1
}

# Convenient standardized path for downstream analysis
ln -sfn \
    "megahit/final.contigs.fa" \
    "$SAMPLE_DIR/${SAMPLE}.final.contigs.fa"

# ============================================================
# seqkit assembly statistics
# ============================================================

seqkit stats -a "$CONTIGS" > "$STATS"

[[ -s "$STATS" ]] || {
    echo "ERROR: seqkit statistics missing"
    exit 1
}

# ============================================================
# Correct contig length statistics
#
# Do NOT parse the MEGAHIT FASTA header with awk fields,
# because MEGAHIT headers contain additional information.
# Here sequence lengths are calculated directly from FASTA.
# ============================================================

python - "$CONTIGS" "$LENGTH_SUMMARY" "$NX_SUMMARY" <<'PY'
import sys

fasta = sys.argv[1]
length_out = sys.argv[2]
nx_out = sys.argv[3]

lengths = []
length = 0

with open(fasta) as f:
    for line in f:
        if line.startswith(">"):
            if length > 0:
                lengths.append(length)
            length = 0
        else:
            length += len(line.strip())

if length > 0:
    lengths.append(length)

if not lengths:
    raise RuntimeError("No contigs found")

# ------------------------------------------------------------
# Length thresholds
# ------------------------------------------------------------

thresholds = [
    500,
    1000,
    1500,
    2000,
    5000,
    10000
]

with open(length_out, "w") as out:
    out.write("Threshold\tContig_count\n")

    for t in thresholds:
        count = sum(x >= t for x in lengths)
        out.write(f">={t}_bp\t{count}\n")

# ------------------------------------------------------------
# N50 / N90
# ------------------------------------------------------------

lengths.sort(reverse=True)

total = sum(lengths)

with open(nx_out, "w") as out:

    out.write("Metric\tValue\n")

    for nx in (50, 90):

        target = total * nx / 100
        cumulative = 0

        for i, length in enumerate(lengths, 1):

            cumulative += length

            if cumulative >= target:

                out.write(f"N{nx}\t{length}\n")
                out.write(f"N{nx}_num\t{i}\n")
                break
PY

# ============================================================
# Final validation
# ============================================================

[[ -s "$LENGTH_SUMMARY" ]] || {
    echo "ERROR: contig length summary missing"
    exit 1
}

[[ -s "$NX_SUMMARY" ]] || {
    echo "ERROR: N50/N90 summary missing"
    exit 1
}

# ============================================================
# Remove MEGAHIT intermediate files after successful assembly
#
# final.contigs.fa is retained.
# Intermediate graphs/contigs are not required downstream.
# ============================================================

if [[ -d "$MEGAHIT_DIR/intermediate_contigs" ]]; then
    rm -rf "$MEGAHIT_DIR/intermediate_contigs"
fi

# ============================================================
# Completion marker
#
# Only generated after:
#   MEGAHIT success
#   final.contigs.fa present
#   seqkit QC present
#   length QC present
#   N50/N90 QC present
# ============================================================

touch "$DONE"

# ============================================================
# Final report
# ============================================================

echo
echo "========================================"
echo "MEGAHIT assembly FINISHED"
echo "========================================"
echo "Sample : $SAMPLE"
echo "Node   : $(hostname)"
echo "Finish : $(date)"
echo "========================================"

echo
echo "===== Assembly statistics ====="
cat "$STATS"

echo
echo "===== Contig length summary ====="
cat "$LENGTH_SUMMARY"

echo
echo "===== N50 / N90 ====="
cat "$NX_SUMMARY"

echo
echo "===== Resource usage ====="
cat "$TIMELOG"

echo
echo "===== Output ====="
ls -lh "$SAMPLE_DIR"
