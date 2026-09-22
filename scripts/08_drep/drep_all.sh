#!/bin/bash

#SBATCH --job-name=drep_all
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=48:00:00
#SBATCH --output=logs/drep_all_%j.out
#SBATCH --error=logs/drep_all_%j.err

set -euo pipefail

STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
INPUT="${MAG_DIR:-$STAGE_DIR/input_mags}"
INFO="${GENOME_INFO:-$STAGE_DIR/genomeInfo.csv}"
OUT="${DREP_OUT:-$STAGE_DIR/drep_95}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate checkm2

N_INPUT=$(find "$INPUT" -maxdepth 1 -type l -name '*.fa' | wc -l)

echo "============================================================"
echo "08 dRep - species-level dereplication"
echo "============================================================"
echo "Node       : $SLURMD_NODENAME"
echo "CPUs       : $SLURM_CPUS_PER_TASK"
echo "Input MAGs : $N_INPUT"
echo "ANI        : 95%"
echo "Start      : $(date)"
echo "============================================================"

if [[ "$N_INPUT" -ne 2672 ]]; then
    echo "ERROR: expected 2672 input MAGs, got $N_INPUT" >&2
    exit 1
fi

if [[ -e "$OUT" ]]; then
    echo "ERROR: output directory already exists: $OUT" >&2
    exit 1
fi

/usr/bin/time -v \
    -o "$STAGE_DIR/drep_all.time.log" \
    dRep dereplicate "$OUT" \
        -g "$INPUT"/*.fa \
        -p "$SLURM_CPUS_PER_TASK" \
        --genomeInfo "$INFO" \
        -comp 50 \
        -con 10 \
        -pa 0.90 \
        -sa 0.95 \
        -nc 0.30 \
        -cm larger \
        --S_algorithm fastANI \
        > "$STAGE_DIR/drep_all.log" 2>&1

if [[ ! -d "$OUT/dereplicated_genomes" ]]; then
    echo "ERROR: dereplicated_genomes missing" >&2
    exit 1
fi

N_REP=$(find "$OUT/dereplicated_genomes" \
    -maxdepth 1 -type f -name '*.fa' | wc -l)

echo
echo "Input MAGs           : $N_INPUT"
echo "Representative MAGs  : $N_REP"

touch "$STAGE_DIR/.drep95.done"

echo
echo "============================================================"
echo "dRep FINISHED"
echo "Finish : $(date)"
echo "============================================================"
