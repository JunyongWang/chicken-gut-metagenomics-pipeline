# Conceptual overview

The workflow is organized around three conceptual analysis paths. Production details are currently verified for stages 01–10.

## Read-level profiling

Raw paired-end reads pass through [fastp quality control](stages/01-fastp.md), [strict chicken-host removal](stages/02-dehost.md), and [Kraken2 plus Bracken taxonomic profiling](stages/03-taxonomy.md).

## Genome-resolved metagenomics

Host-removed reads support [individual-sample MEGAHIT assembly](stages/04-assembly.md), [read mapping plus contig-depth estimation](stages/05-mapping-depth.md), [multi-binner MAG reconstruction](stages/06-binning.md), [CheckM2 quality assessment](stages/07-checkm2.md), [species-level dereplication](stages/08-drep.md), [GTDB-Tk classification](stages/09-gtdbtk.md), and [CoverM MAG abundance](stages/10-coverm.md).

## Functional characterization

Assemblies and MAGs support gene catalog construction, functional annotation, CAZyme analysis, KEGG Orthology analysis, and functional abundance estimation.

Stages 01–10 document verified commands, parameters, resources, integrity checks, and aggregate QC from archived production sources. Stages 11–13 remain unverified placeholders.
