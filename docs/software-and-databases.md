# Software and databases

## Scope

This page inventories verified software and reference databases for stages 01–12. Stage 13 remains pending.

## Verified inventory

| Stage | Software | Verified version |
| --- | --- | --- |
| 01 | fastp | 1.3.6 |
| 02 and 05 | Bowtie2 | 2.5.5 |
| 03 | Kraken2 | 2.17.1 |
| 03 | Bracken | 3.0.1 |
| 04 | MEGAHIT | 1.2.9 |
| 06 | MetaBAT2 | 2.12.1 |
| 06 | MetaWRAP | 1.3.2 |
| 06 | MaxBin2 | Not captured in the archived production record. |
| 06 | CONCOCT | Not captured in the archived production record. |
| 07 | CheckM2 | 1.1.0 |
| 08 | dRep | 3.7.1 |
| 08 | fastANI | 1.34 |
| 08 | Mash | 2.3 |
| 09 | GTDB-Tk | 2.6.1 |
| 10 | CoverM | 0.8.0 |
| 10 | minimap2 | 2.31-r1302 |
| 11A and 11B | Prodigal | 2.6.3 |
| 11A | MMseqs2 | 18.8cc5c |
| 11A | Salmon | 2.7.0 |
| 11A | seqkit | Not captured in the archived production record. |
| 12A | eggNOG-mapper | 2.1.15 |
| 12B | dbCAN | 5.2.9 |

Exact versions of samtools, seqkit, `jgi_summarize_bam_contig_depths`, and dbCAN's underlying helper executables were not all captured in the archived environment snapshot.

## Verified references

- Stage 02: chicken GRCg7b Bowtie2 index
- Stage 03: Kraken2/Bracken database `standard_20260626`
- Stage 07: CheckM2 UniRef100 KO database file `uniref100.KO.1.dmnd`
- Stage 09: GTDB release R226
- Stage 12A: eggNOG database 5.0.2
- Stage 12B: dbCAN 5.2.9 database containing `CAZy.dmnd`, `dbCAN.hmm`, `dbCAN-sub.hmm`, and `fam-substrate-mapping.tsv`

Database acquisition dates, checksums, and build procedures are documented only where retained in the production archive; otherwise they are not reconstructed.
