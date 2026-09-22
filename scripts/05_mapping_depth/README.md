# Stage 05 reference scripts

- `mapping_depth_array.sh`: per-sample index, mapping, BAM validation, and mother depth-table generation
- `make_mapping_QC.py`: archived production cross-sample QC table generator

Required variables are `PROJECT_ROOT` and `CONDA_SH`. Optional variables configure the environment, work root, stage directory, dehost root, assembly root, and sample list. The QC helper accepts `SAMPLES_FILE`, `ASSEMBLY_DIR`, and `OUTFILE`.

The script preserves `1-60%10`, mapping and sorting flags, 97% depth identity, absence of contig-length filtering, row-count validation, cleanup, and marker logic.
