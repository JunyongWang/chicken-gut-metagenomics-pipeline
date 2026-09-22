#!/bin/bash

#SBATCH --job-name=magbin_array
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=24:00:00

#SBATCH --array=1-60

#SBATCH --output=logs/binning_%A_%a.out
#SBATCH --error=logs/binning_%A_%a.err


set -euo pipefail

STAGE_DIR="${STAGE_DIR:-$SLURM_SUBMIT_DIR}"
WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
SAMPLES_FILE="${SAMPLES_FILE:-$STAGE_DIR/samples.txt}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate mag_binning


# ============================================================
# 根据 array task ID 获取样本
# ============================================================

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLES_FILE")

if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: no sample for array task ${SLURM_ARRAY_TASK_ID}" >&2
    exit 1
fi


OUT="$WORK_ROOT/06_binning/$SAMPLE"


echo "============================================================"
echo "06 MAG BINNING ARRAY"
echo "============================================================"
echo "Array task : $SLURM_ARRAY_TASK_ID"
echo "Sample     : $SAMPLE"
echo "Job ID     : $SLURM_JOB_ID"
echo "Node       : $SLURMD_NODENAME"
echo "CPUs       : $SLURM_CPUS_PER_TASK"
echo "Start      : $(date)"
echo "============================================================"


# ============================================================
# 已成功样本直接跳过
#
# 因此 M1 已经有 .binning.done，
# task 1 会自动跳过，不重复花钱。
# ============================================================

if [[ -f "$OUT/.binning.done" ]]; then
    echo
    echo "$SAMPLE already completed. SKIP."
    exit 0
fi


# ============================================================
# 调用已经由 M1 验证成功的正式 worker
# ============================================================

bash "$STAGE_DIR/binning_worker.sh" "$SAMPLE"


echo
echo "============================================================"
echo "$SAMPLE ARRAY TASK FINISHED"
echo "Finish: $(date)"
echo "============================================================"
