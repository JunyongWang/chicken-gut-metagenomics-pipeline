# Stage 10 reference scripts

- `coverm_makedb.sh`: build the 374-MAG minimap2-sr database
- `coverm_array.sh`: quantify 60 samples with the frozen filtering rules
- `merge_coverm.py`: validate and merge per-sample results into four matrices
- `make_MAG_catalog.py`: integrate CheckM2, GTDB-Tk, and CoverM summaries

The shell scripts require `CONDA_SH`; documented environment variables expose stage, work, sample-list, MAG, index, report, summary, and output locations without changing analytical settings.
