# Stage 03 reference scripts

- `kraken_bracken_array.sh`: Kraken2 and six-level Bracken production workflow
- `summarize_kraken.py`: archived production QC summarizer
- `make_bracken_matrices.py`: archived production count and relative-abundance matrix builder

Required variables are `PROJECT_ROOT`, `KRAKEN_DB`, and `CONDA_SH`. `KRAKEN_DB` must point to `standard_20260626`. Optional variables configure the environment, work root, stage directory, dehost root, and sample list. The Python helpers accept `SAMPLES_FILE` where applicable.

The script preserves `1-60%6`, all Kraken2/Bracken flags, validation, compression, and marker logic. Production-site scheduler settings are documented separately.
