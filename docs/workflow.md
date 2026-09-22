# Conceptual workflow

The diagram shows the workflow relationships. Stages 01–05 now have verified production documentation; downstream stages remain conceptual.

```mermaid
flowchart TB
    accTitle: Conceptual metagenomics workflow
    accDescr: Three connected conceptual paths show read-level profiling, genome-resolved analysis, and functional characterization without implementation details.

    subgraph read_level ["Read-level profiling"]
        raw_fastq["Raw FASTQ"] --> qc["01 fastp QC"] --> host_removal["02 Bowtie2 host removal"] --> taxonomy["03 Kraken2 and Bracken"]
    end

    subgraph genome_resolved ["Genome-resolved metagenomics"]
        host_removed_reads["Host-removed reads"] --> assembly["04 MEGAHIT assembly"] --> mapping_depth["05 Mapping and depth"] --> binning["Binning"] --> mag_qc["MAG QC"] --> dereplication["Dereplication"] --> mag_taxonomy["Taxonomy and MAG abundance"]
    end

    subgraph functional ["Functional characterization"]
        assembly_mags["Assembly or MAGs"] --> gene_catalogs["Gene catalogs"] --> eggnog["eggNOG"] --> dbcan["dbCAN"] --> functional_abundance["KO and CAZyme abundance"]
    end

    host_removal --> host_removed_reads
    assembly --> assembly_mags
```

Verified stage pages: [01](stages/01-fastp.md), [02](stages/02-dehost.md), [03](stages/03-taxonomy.md), [04](stages/04-assembly.md), and [05](stages/05-mapping-depth.md).
