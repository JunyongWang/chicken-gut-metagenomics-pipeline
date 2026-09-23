# Conceptual workflow

The diagram shows the verified relationships through Stage 12. Stage 13 remains pending.

```mermaid
flowchart TB
    accTitle: Chicken gut metagenomics workflow through Stage 12
    accDescr: Read-level profiling and genome-resolved analysis feed two Stage 11 gene catalogs, which are annotated with eggNOG and dbCAN and summarized as community and MAG-weighted CAZyme outputs.

    subgraph read_level ["Read-level profiling"]
        raw_fastq["Raw FASTQ"] --> qc["01 fastp QC"] --> host_removal["02 Bowtie2 host removal"] --> taxonomy["03 Kraken2 and Bracken"]
    end

    subgraph genome_resolved ["Genome-resolved metagenomics"]
        host_removed_reads["Host-removed reads"] --> assembly["04 MEGAHIT assembly"] --> mapping_depth["05 Mapping and depth"] --> binning["06 Multi-binner reconstruction"] --> mag_qc["07 CheckM2 MAG QC"] --> dereplication["08 dRep dereplication"] --> mag_taxonomy["09 GTDB-Tk taxonomy"] --> mag_abundance["10 CoverM MAG TPM"]
    end

    subgraph functional ["Functional characterization"]
        community_assemblies["60 individual assemblies"] --> community_catalog["11A Community NR catalog"]
        community_catalog --> community_gene_abundance["Gene TPM / NumReads"]
        community_catalog --> eggnog_nr["12A eggNOG NR"] --> dbcan_nr["12B dbCAN NR"] --> nr_cazyme["NR CAZyme-family abundance"]
        community_gene_abundance --> nr_cazyme

        representative_mags["374 representative MAGs"] --> mag_catalog["11B MAG-specific catalog"]
        mag_catalog --> eggnog_mag["12A eggNOG MAG"] --> dbcan_mag["12B dbCAN MAG"] --> mag_cazyme_counts["MAG × CAZyme family counts"]
        mag_abundance --> weighted_cazyme["MAG-weighted CAZyme TPM"]
        mag_cazyme_counts --> weighted_cazyme
    end

    host_removal --> host_removed_reads
    assembly --> community_assemblies
    dereplication --> representative_mags
```

Verified stage pages: [01](stages/01-fastp.md), [02](stages/02-dehost.md), [03](stages/03-taxonomy.md), [04](stages/04-assembly.md), [05](stages/05-mapping-depth.md), [06](stages/06-binning.md), [07](stages/07-checkm2.md), [08](stages/08-drep.md), [09](stages/09-gtdbtk.md), [10](stages/10-coverm.md), [11](stages/11-gene-catalog.md), and [12](stages/12-functional-annotation.md).
