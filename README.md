# Chicken gut metagenomics pipeline

[![Documentation](https://github.com/JunyongWang/chicken-gut-metagenomics-pipeline/actions/workflows/docs.yml/badge.svg)](https://github.com/JunyongWang/chicken-gut-metagenomics-pipeline/actions/workflows/docs.yml)

A reproducible, production-derived workflow for chicken gut metagenomics, covering read preprocessing, taxonomic profiling, genome-resolved metagenomics, gene catalogs, functional annotation, CAZyme analysis, and KEGG Orthology abundance.

**Documentation:** https://junyongwang.github.io/chicken-gut-metagenomics-pipeline/

## Status

The repository documents the verified production workflow through **Stages 01–13**. Analytical parameters, frozen thresholds, resource requests where archived, integrity checks, and aggregate QC values were reconstructed from retained production scripts and verified project summaries.

The public reference scripts preserve analytical behavior while replacing site-specific HPC paths and account details with configurable variables. When a historical submission detail was not retained, the documentation says so rather than reconstructing it.

## Workflow scope

| Stage | Analysis |
| --- | --- |
| 01 | fastp read quality control |
| 02 | Bowtie2 chicken-host removal |
| 03 | Kraken2/Bracken taxonomic profiling |
| 04 | Per-sample MEGAHIT assembly |
| 05 | Read mapping and contig-depth estimation |
| 06 | MetaBAT2, MaxBin2, CONCOCT, and MetaWRAP bin refinement |
| 07 | CheckM2 MAG quality assessment |
| 08 | dRep dereplication |
| 09 | GTDB-Tk taxonomy |
| 10 | CoverM MAG abundance |
| 11A | Community non-redundant gene catalog and Salmon abundance |
| 11B | MAG-specific gene catalog |
| 12A | eggNOG functional annotation |
| 12B | dbCAN CAZyme annotation and CAZyme abundance summaries |
| 13 | Community and MAG-weighted KEGG Orthology abundance |

See the [conceptual workflow](docs/workflow.md) and individual [stage documentation](docs/index.md) for exact commands and verified outputs.

## Repository layout

\`\`\`text
config/                     Versioned manifests used by portable scripts
docs/                       MkDocs documentation
docs/stages/                Stage 01–13 protocols and verified QC
scripts/                    Portable production-reference scripts
.github/workflows/docs.yml  Strict documentation build and Pages deployment
mkdocs.yml                  Documentation-site configuration
\`\`\`

Raw sequencing reads, reference databases, assembled genomes, BAM files, large abundance matrices, and source-of-truth handoff archives are intentionally not stored in this repository.

## Build the documentation locally

\`\`\`bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-docs.txt
mkdocs serve
\`\`\`

For the same validation used in CI:

\`\`\`bash
mkdocs build --strict
\`\`\`

## Reproducibility and provenance

The workflow distinguishes verified production facts from portability refactors. Stage pages record the inputs, software versions, parameters, Slurm resources where captured, outputs, QC, verified results, and frozen methodological decisions.

See:

- [Reproducibility](docs/reproducibility.md)
- [Software and databases](docs/software-and-databases.md)
- [Outputs](docs/outputs.md)
- [Server and environment](docs/server-and-environment.md)

## Data and security

No credentials, private access URLs, raw sequencing data, or production database archives are required by the repository. Site-specific usernames, host addresses, account names, private storage paths, and temporary transfer credentials are not part of the portable workflow.

## License

No open-source license has been selected yet. Add a license before treating the repository as an openly reusable software distribution.
