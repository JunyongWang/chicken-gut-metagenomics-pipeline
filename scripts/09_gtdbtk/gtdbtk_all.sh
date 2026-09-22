#!/bin/bash

#SBATCH --job-name=gtdb_all
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=200G
#SBATCH --time=48:00:00
#SBATCH --output=logs/gtdb_all_%j.out
#SBATCH --error=logs/gtdb_all_%j.err

set -euo pipefail

STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"
: "${GTDBTK_DATA_PATH:?Set GTDBTK_DATA_PATH to the GTDB R226 data directory}"
export GTDBTK_DATA_PATH
INPUT="${MAG_DIR:-$STAGE_DIR/input_mags}"
OUT="${GTDBTK_OUT:-$STAGE_DIR/gtdbtk_r226}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate gtdbtk

N_MAG=$(find "$INPUT" -maxdepth 1 -type l -name '*.fa' | wc -l)

echo "============================================================"
echo "09 GTDB-Tk formal classification"
echo "============================================================"
echo "Node       : $SLURMD_NODENAME"
echo "CPUs       : $SLURM_CPUS_PER_TASK"
echo "MAGs       : $N_MAG"
echo "GTDB-Tk    : $(gtdbtk --version)"
echo "Database   : $GTDBTK_DATA_PATH"
echo "Start      : $(date)"
echo "============================================================"

if [[ "$N_MAG" -ne 374 ]]; then
    echo "ERROR: expected 374 MAGs, got $N_MAG" >&2
    exit 1
fi

if [[ -e "$OUT" ]]; then
    echo "ERROR: output directory already exists: $OUT" >&2
    exit 1
fi

/usr/bin/time -v \
    -o "$STAGE_DIR/gtdbtk_all.time.log" \
    gtdbtk classify_wf \
        --genome_dir "$INPUT" \
        --out_dir "$OUT" \
        --extension fa \
        --cpus "$SLURM_CPUS_PER_TASK" \
        --pplacer_cpus 4 \
        > "$STAGE_DIR/gtdbtk_all.log" 2>&1

touch "$STAGE_DIR/.gtdbtk.done"

echo
echo "============================================================"
echo "GTDB-Tk FINISHED"
echo "Finish : $(date)"
echo "============================================================"
