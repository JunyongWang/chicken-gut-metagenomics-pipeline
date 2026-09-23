# Chicken gut metagenomics pipeline

This site documents the verified production workflow for a 60-sample chicken gut metagenomics project, from raw-read preprocessing through genome-resolved metagenomics and KO-level functional abundance.

All production stages **01–13** are documented. Each stage records the retained analytical commands, software/database versions where captured, computational resources where archived, output validation, aggregate QC, and frozen methodological decisions.

## Start here

- [Conceptual overview](overview.md) — how the three analysis paths connect
- [Workflow diagram](workflow.md) — read-level, genome-resolved, and functional branches
- [Reproducibility](reproducibility.md) — source precedence and portability rules
- [Software and databases](software-and-databases.md) — verified versions and references
- [Outputs](outputs.md) — formal output groups and completion markers

## Pipeline stages

The stage pages cover:

1. read QC and host removal;
2. taxonomic profiling;
3. per-sample assembly and contig-depth estimation;
4. multi-binner MAG reconstruction, quality filtering, dereplication, taxonomy, and abundance;
5. community and MAG-specific gene catalogs;
6. eggNOG and dbCAN functional annotation;
7. community CAZyme/KO abundance and MAG-abundance-weighted functional summaries.

Use the navigation sidebar for exact stage-level parameters and validated results.

## Reproducibility boundary

The repository is production-derived, not a synthetic reimplementation. When the archive retained an exact command or threshold, the portable reference script preserves it. When a historical detail such as a submission-time array concurrency was not retained, it is explicitly documented as not captured rather than inferred.

Large biological data, reference databases, source-of-truth handoff archives, credentials, and private infrastructure details are intentionally excluded from the repository.
