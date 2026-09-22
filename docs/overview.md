# Conceptual overview

The workflow is organized around three conceptual analysis paths. Production details are currently verified for stages 01–05 only.

## Read-level profiling

Raw paired-end reads pass through [fastp quality control](stages/01-fastp.md), [strict chicken-host removal](stages/02-dehost.md), and [Kraken2 plus Bracken taxonomic profiling](stages/03-taxonomy.md).

## Genome-resolved metagenomics

Host-removed reads support [individual-sample MEGAHIT assembly](stages/04-assembly.md) and [read mapping plus contig-depth estimation](stages/05-mapping-depth.md). Binning, MAG quality assessment, dereplication, taxonomic assignment, and MAG abundance remain placeholders pending later source batches.

## Functional characterization

Assemblies and MAGs support gene catalog construction, functional annotation, CAZyme analysis, KEGG Orthology analysis, and functional abundance estimation.

Stages 01–05 document verified commands, parameters, resources, integrity checks, and aggregate QC from the archived production source. Stages 06–13 remain unverified placeholders.
