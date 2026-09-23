# Stage 12 functional analysis scripts

Portable reference scripts for the verified Stage 12 production workflow are grouped into:

- `eggnog/` — eggNOG-mapper annotation of the community NR and MAG protein catalogs
- `dbcan/` — dbCAN CAZyme annotation and recommended-gene merging
- `cazyme/` — CAZy parent-family abundance, MAG × family counts, and MAG-weighted CAZyme TPM

The scripts preserve analytical parameters, expected counts, Slurm CPU/memory/wall-time requests, QC logic, and completion markers from the archived production workflow. Site-specific account/partition/exclusion directives and private absolute paths are replaced by configurable variables.

Historical benchmark/test scripts, database-copy helpers, and dbCAN wrong-method outputs are intentionally excluded.
