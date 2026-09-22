# Stage 02 reference scripts

- `bowtie2_dehost_array.sh`: portable Slurm reference preserving the strict both-mates-unmapped host filter
- `summarize_dehost.py`: archived production QC summarizer

Required variables are `PROJECT_ROOT`, `HOST_INDEX`, and `CONDA_SH`. Optional variables configure the environment, work root, stage directory, fastp directory, and sample list. `HOST_INDEX` must be the chicken GRCg7b Bowtie2 index prefix.

The original array range and concurrency are not captured and are intentionally absent. Production-site scheduler settings are documented in the stage page.
