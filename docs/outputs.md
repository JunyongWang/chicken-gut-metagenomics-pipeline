# Outputs

## Scope

This page catalogs verified output groups for stages 01–10.

## Verified outputs

| Stage | Primary outputs | Completion marker |
| --- | --- | --- |
| 01 | Clean paired FASTQ, fastp HTML/JSON | `.fastp.done` |
| 02 | Host-removed paired FASTQ, mapping/conversion logs | `.dehost.done` |
| 03 | Kraken report/output, six Bracken levels | `.kraken_bracken.done` |
| 04 | Final contigs, standardized symlink, assembly QC | `.assembly.done` |
| 05 | Sorted BAM/BAI, flagstat, mother depth table | `.mapping_depth.done` |
| 06 | Three binner outputs, MetaWRAP refined candidates, sample-prefixed bins | `.metabat2.done`, `.maxbin2.done`, `.concoct.done`, `.refinement.done`, `.binning.done` |
| 07 | CheckM2 `quality_report.tsv` | `.checkm2.done` |
| 08 | dRep work directory and 374 representatives | `.drep95.done` |
| 09 | GTDB-Tk R226 classifications and bacterial summary | `.gtdbtk.done` |
| 10 | CoverM database, per-sample tables, four matrices, mapping summary, MAG catalog | `.makedb.done`, per-sample `.coverm.done` |

Detailed names and validation conditions are recorded on each stage page. Outputs for stages 11–13 remain pending.
