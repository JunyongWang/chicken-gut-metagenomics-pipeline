# Stage 06 reference scripts

- `binning_array.sh`: 60-sample Slurm array entry point
- `binning_worker.sh`: checkpoint-aware MetaBAT2, MaxBin2, CONCOCT, and MetaWRAP worker

Set `WORK_ROOT` and `CONDA_SH`. Optional overrides are `STAGE_DIR` and `SAMPLES_FILE`. Site-specific partition, account, QoS, and node exclusions are documented but intentionally not embedded in these portable references.
