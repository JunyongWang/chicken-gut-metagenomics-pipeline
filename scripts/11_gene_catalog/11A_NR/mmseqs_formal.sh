#!/bin/bash
#SBATCH --job-name=mmseqs_NR
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=450G
#SBATCH --time=48:00:00
#SBATCH --output=logs/mmseqs_NR_%j.out
#SBATCH --error=logs/mmseqs_NR_%j.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/11_gene_catalog/11A_NR}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate gene_catalog

OUTDIR="$STAGE_DIR/nr"

INPUT="$OUTDIR/all_genes.min100.ffn"

PREFIX="$OUTDIR/mmseqs95_90"
TMP="$OUTDIR/mmseqs_tmp"

REP="${PREFIX}_rep_seq.fasta"
CLUSTER="${PREFIX}_cluster.tsv"
ALLSEQ="${PREFIX}_all_seqs.fasta"

FINAL_FFN="$OUTDIR/NR_gene_catalog.ffn"
FINAL_CLUSTER="$OUTDIR/NR_gene_clusters.tsv"
SUMMARY="$OUTDIR/mmseqs_summary.tsv"
DONE="$OUTDIR/.mmseqs95_90.done"

EXPECTED=28098350

echo "============================================================"
echo "MMseqs2 formal NR gene catalog"
echo "Node       : $(hostname)"
echo "CPUs       : $SLURM_CPUS_PER_TASK"
echo "Memory     : 450G"
echo "Input      : $INPUT"
echo "Genes      : $EXPECTED"
echo "Identity   : 0.95"
echo "Coverage   : 0.90"
echo "Cov mode   : 0"
echo "Max seq    : 65535"
echo "Start      : $(date)"
echo "============================================================"

# ------------------------------------------------------------
# checkpoint
# ------------------------------------------------------------

if [[ -f "$DONE" && -s "$FINAL_FFN" && -s "$FINAL_CLUSTER" ]]; then
    echo "MMseqs2 already complete, skip."
    exit 0
fi

[[ -s "$INPUT" ]] || {
    echo "ERROR: missing input: $INPUT"
    exit 1
}

# ------------------------------------------------------------
# clean previous incomplete formal run
# ------------------------------------------------------------

rm -f \
    "$DONE" \
    "$REP" \
    "$CLUSTER" \
    "$ALLSEQ" \
    "$FINAL_FFN" \
    "$FINAL_CLUSTER" \
    "$SUMMARY"

rm -rf "$TMP"

# ------------------------------------------------------------
# MMseqs2 clustering
# 95% nucleotide identity
# 90% bidirectional coverage
# ------------------------------------------------------------

/usr/bin/time -v \
    -o "$OUTDIR/mmseqs_formal.time.log" \
    mmseqs easy-cluster \
        "$INPUT" \
        "$PREFIX" \
        "$TMP" \
        --min-seq-id 0.95 \
        -c 0.90 \
        --cov-mode 0 \
        --max-seq-len 65535 \
        --split-memory-limit 360G \
        --threads "$SLURM_CPUS_PER_TASK" \
        > "$OUTDIR/mmseqs_formal.log" 2>&1

# ------------------------------------------------------------
# output check
# ------------------------------------------------------------

[[ -s "$REP" ]] || {
    echo "ERROR: representative FASTA missing"
    exit 1
}

[[ -s "$CLUSTER" ]] || {
    echo "ERROR: cluster TSV missing"
    exit 1
}

REP_N=$(grep -c '^>' "$REP")
MEMBER_N=$(wc -l < "$CLUSTER")

echo
echo "Input genes       : $EXPECTED"
echo "Representative    : $REP_N"
echo "Cluster TSV rows  : $MEMBER_N"

if [[ "$MEMBER_N" -ne "$EXPECTED" ]]; then
    echo "ERROR: cluster membership count mismatch"
    exit 1
fi

if [[ "$REP_N" -le 0 || "$REP_N" -gt "$EXPECTED" ]]; then
    echo "ERROR: invalid representative count"
    exit 1
fi

REDUCTION=$(awk -v r="$REP_N" -v n="$EXPECTED" \
    'BEGIN{printf "%.4f",100*(1-r/n)}')

# ------------------------------------------------------------
# final standardized output names
# ------------------------------------------------------------

mv "$REP" "$FINAL_FFN"
mv "$CLUSTER" "$FINAL_CLUSTER"

printf "Input_genes\tRepresentative_genes\tReduction_percent\tIdentity\tCoverage\tCov_mode\n" \
    > "$SUMMARY"

printf "%s\t%s\t%s\t0.95\t0.90\t0\n" \
    "$EXPECTED" "$REP_N" "$REDUCTION" \
    >> "$SUMMARY"

# Remove the redundant all_seqs helper output from easy-cluster.
rm -f "$ALLSEQ"

# Remove the MMseqs temporary directory after successful completion.
rm -rf "$TMP"

touch "$DONE"

echo
echo "Reduction (%)    : $REDUCTION"
echo
echo "===== final files ====="
ls -lh \
    "$FINAL_FFN" \
    "$FINAL_CLUSTER" \
    "$SUMMARY"

echo
echo "Finish : $(date)"
echo "============================================================"
