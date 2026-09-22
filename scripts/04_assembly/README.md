# Stage 04 reference scripts

- `megahit_array.sh`: individual-sample MEGAHIT assembly and in-task assembly QC
- `make_assembly_QC.py`: archived production cross-sample QC table generator

Required variables are `PROJECT_ROOT` and `CONDA_SH`. Optional variables configure the environment, work root, stage directory, dehost root, and sample list. The QC helper accepts `SAMPLES_FILE` and `OUTFILE`.

The script preserves `1-60%9`, the production MEGAHIT parameters, standardized contig symlink, direct FASTA length calculation, QC validation, cleanup, and marker logic.
