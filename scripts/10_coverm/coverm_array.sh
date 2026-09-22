#!/bin/bash

#SBATCH --job-name=coverm
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=12G
#SBATCH --time=03:00:00
#SBATCH --array=1-60%10
#SBATCH --output=logs/coverm_%A_%a.out
#SBATCH --error=logs/coverm_%A_%a.err

set -euo pipefail

STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
SAMPLES_FILE="${SAMPLES_FILE:-$STAGE_DIR/samples.txt}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
COVERM_INDEX="${COVERM_INDEX:-$STAGE_DIR/db/minimap2_sr/coverm_concatenated_genomes.fna.minimap2-sr.mmi}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate metagenomics

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLES_FILE")

if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: empty sample for array task $SLURM_ARRAY_TASK_ID" >&2
    exit 1
fi

R1="$WORK_ROOT/02_dehost/$SAMPLE/${SAMPLE}_R1.dehost.fq.gz"
R2="$WORK_ROOT/02_dehost/$SAMPLE/${SAMPLE}_R2.dehost.fq.gz"

REF="$COVERM_INDEX"

OUTDIR="$STAGE_DIR/results/$SAMPLE"
OUT="$OUTDIR/${SAMPLE}.coverm.tsv"
TMP="$OUTDIR/${SAMPLE}.coverm.tsv.tmp"
DONE="$OUTDIR/.coverm.done"

mkdir -p "$OUTDIR"

if [[ -f "$DONE" && -s "$OUT" ]]; then
    N=$(wc -l < "$OUT")
    if [[ "$N" -eq 376 ]]; then
        echo "$SAMPLE already complete, skip."
        exit 0
    fi
fi

[[ -s "$R1" ]] || { echo "ERROR: missing $R1" >&2; exit 1; }
[[ -s "$R2" ]] || { echo "ERROR: missing $R2" >&2; exit 1; }
[[ -s "$REF" ]] || { echo "ERROR: missing $REF" >&2; exit 1; }

rm -f "$TMP" "$DONE"

echo "============================================================"
echo "CoverM formal quantification"
echo "============================================================"
echo "Sample : $SAMPLE"
echo "Node   : $SLURMD_NODENAME"
echo "CPUs   : $SLURM_CPUS_PER_TASK"
echo "Start  : $(date)"
echo "============================================================"

/usr/bin/time -v \
    -o "$OUTDIR/${SAMPLE}.time.log" \
    coverm genome \
        -p minimap2-sr \
        --reference "$REF" \
        --minimap2-reference-is-index \
        -s '~' \
        -1 "$R1" \
        -2 "$R2" \
        --threads "$SLURM_CPUS_PER_TASK" \
        --min-read-percent-identity 95 \
        --min-read-aligned-percent 75 \
        --methods \
            mean \
            covered_fraction \
            relative_abundance \
            tpm \
        > "$TMP" \
        2> "$OUTDIR/${SAMPLE}.coverm.log"

N=$(wc -l < "$TMP")

if [[ "$N" -ne 376 ]]; then
    echo "ERROR: $SAMPLE expected 376 output lines, got $N" >&2
    exit 1
fi

mv "$TMP" "$OUT"
touch "$DONE"

echo
echo "Output lines : $N"
echo "Finish       : $(date)"
echo "============================================================"
