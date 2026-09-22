# 11A community NR reference scripts

These scripts implement per-sample metagenomic Prodigal prediction, the 100-bp CDS filter, nucleotide MMseqs2 clustering, exact NR protein extraction, Salmon indexing and quantification, and abundance-matrix merging.

Set `PROJECT_ROOT`, `WORK_ROOT`, and `CONDA_SH`. Optional location overrides include `STAGE_DIR`, `ASSEMBLY_ROOT`, `DEHOST_ROOT`, and `SAMPLE_LIST`. By default, `SAMPLE_LIST` uses `config/samples.txt` under `PROJECT_ROOT`.
