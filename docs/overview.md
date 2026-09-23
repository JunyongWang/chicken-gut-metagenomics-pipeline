# Conceptual overview

The workflow is organized around three conceptual analysis paths. Production details are verified for stages 01–13.

## Read-level profiling

Raw paired-end reads pass through [fastp quality control](stages/01-fastp.md), [strict chicken-host removal](stages/02-dehost.md), and [Kraken2 plus Bracken taxonomic profiling](stages/03-taxonomy.md).

## Genome-resolved metagenomics

Host-removed reads support [individual-sample MEGAHIT assembly](stages/04-assembly.md), [read mapping plus contig-depth estimation](stages/05-mapping-depth.md), [multi-binner MAG reconstruction](stages/06-binning.md), [CheckM2 quality assessment](stages/07-checkm2.md), [species-level dereplication](stages/08-drep.md), [GTDB-Tk classification](stages/09-gtdbtk.md), and [CoverM MAG abundance](stages/10-coverm.md).

## Functional characterization

Stage 11 contains two distinct gene workflows: a [community non-redundant gene catalog and abundance branch](stages/11-gene-catalog.md#11a-community-non-redundant-gene-catalog) from 60 individual assemblies and a [MAG-specific gene catalog](stages/11-gene-catalog.md#11b-mag-specific-gene-catalog) from 374 representatives.

[Stage 12](stages/12-functional-annotation.md) annotates both protein catalogs with eggNOG-mapper, performs dbCAN CAZyme annotation, aggregates community NR CAZyme-family abundance, builds a MAG × CAZyme family gene-count matrix, and derives MAG-abundance-weighted CAZyme TPM.

[Stage 13](stages/13-functional-abundance.md) parses eggNOG `KEGG_ko` assignments to produce community NR KO TPM/NumReads matrices, a 374-MAG × KO gene-count matrix, and MAG-abundance-weighted KO TPM. The verified workflow ends at KO-level outputs; it does not reconstruct KEGG pathway/module abundance.

Stages 01–13 document verified production commands, parameters, archived resources where available, integrity checks, and aggregate QC. Missing historical submission details are explicitly left undocumented rather than inferred.
