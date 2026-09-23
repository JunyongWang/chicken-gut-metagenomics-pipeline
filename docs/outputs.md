# Outputs

## Scope

This page catalogs verified output groups for stages 01–13.

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
| 11A | Community NR nucleotide/protein catalogs, cluster membership, Salmon results, TPM and NumReads matrices | `.prodigal.done`, `.merge_ffn.done`, `.mmseqs95_90.done`, `.nr_protein.done`, `.salmon_index.done`, `.salmon.done`, `.merge_salmon.done` |
| 11B | MAG-specific nucleotide/protein catalogs, gene-to-MAG mapping, per-MAG summary | `.prodigal.done`, `.merge_MAG_genes.done` |
| 12A | NR and MAG eggNOG annotations, seed orthologs, chunk/batch QC, final summaries | `.split.done`, `.eggnog.done`, `.search.done`, `.annotation.done`, merge `.done` markers |
| 12B | NR and MAG dbCAN overview/recommended tables, NR family abundance matrices, MAG × family matrix, MAG-weighted CAZyme TPM | `.dbcan.done`, merge `.done`, `.abundance.done` where wrapped |
| 13A | NR gene-to-KO map, KO TPM/NumReads matrices, abundance QC, summary | `.ko_abundance.done` |
| 13B | MAG gene-to-KO map, MAG × KO gene-count matrix, KO totals, MAG and global summaries | No formal completion marker retained |
| 13C | MAG-weighted KO TPM, per-sample conservation QC, weighted summary | No formal completion marker retained |

Detailed names and validation conditions are recorded on each stage page. The verified formal workflow ends at KO-level Stage 13 outputs; no downstream KEGG pathway/module matrix is reconstructed.
