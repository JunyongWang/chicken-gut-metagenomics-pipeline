# Stage 01 reference scripts

- `fastp_array.sh`: portable Slurm reference preserving the production fastp flags and 8 CPU/16G/4-hour request
- `summarize_fastp.py`: archived production QC summarizer

Required variables are `PROJECT_ROOT`, `RAW_DIR`, and `CONDA_SH`. Optional variables are `CONDA_ENV`, `STAGE_DIR`, and `SAMPLE_LIST`. Submit from a stage output directory containing `logs/`. The original array range and concurrency are not captured in the archived production script and are intentionally absent.

Production-site partition, account, QoS, and node exclusion are documented in the stage page but omitted from this portable script.
