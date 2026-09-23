# Stage 11 — Gene catalogs

Stage 11 contains two separate production workflows. Branch 11A constructs and quantifies a community non-redundant gene catalog from individual assemblies. Branch 11B predicts and merges genes from dereplicated representative MAGs. Their inputs, Prodigal modes, filtering, outputs, and downstream roles are distinct.

## 11A — Community non-redundant gene catalog

### Purpose

Construct a nucleotide non-redundant catalog from genes predicted independently in 60 assemblies, derive the corresponding protein catalog, quantify host-removed reads against the nucleotide catalog, and merge gene-abundance matrices.

### Input

- Sixty individual Stage 04 assemblies: M1–M61 excluding M23
- Stage 02 host-removed paired reads for the same 60 samples
- The ordered repository manifest `config/samples.txt`

This branch uses individual assemblies and is not a co-assembly.

### Gene prediction

Prodigal 2.6.3 runs once per sample. Contig identifiers are prefixed with the sample ID before prediction. The formal mode is `-p meta`, and nucleotide CDS, protein CDS, and GFF outputs are generated.

### Gene-length filtering

Nucleotide CDS of at least 100 bp are retained with `seqkit seq -m 100`. Exact retained gene IDs are then used to select matching proteins. The exact seqkit version was not captured in the archived production record.

### Gene merging

Exactly 60 filtered nucleotide-gene FASTA files are concatenated. The merge requires exactly 28,098,350 genes.

### MMseqs2 clustering

MMseqs2 18.8cc5c performs nucleotide clustering of the predicted CDS with `mmseqs easy-cluster`.

```text
--min-seq-id 0.95
-c 0.90
--cov-mode 0
--max-seq-len 65535
--split-memory-limit 360G
--threads 16
```

This is nucleotide CDS clustering, not protein clustering.

### NR protein extraction

Representative gene IDs are read from `NR_gene_catalog.ffn`. Proteins with those exact IDs are extracted from the 60 filtered per-sample protein FASTA files. The expected output is `NR_gene_catalog.faa` with 13,151,701 proteins.

### Salmon indexing

Salmon 2.7.0 indexes `NR_gene_catalog.ffn`, which must contain 13,151,701 genes.

```text
salmon index -k 31 -p 8 --keepDuplicates --no-clip
```

### Salmon quantification

Each sample's Stage 02 host-removed paired reads are quantified with:

```text
salmon quant -l A -p 4 --meta
```

Each successful `quant.sf` must have 13,151,701 data rows plus one header.

### Abundance-matrix merging

`merge_salmon.py` requires exactly 60 non-empty `quant.sf` files, the canonical five-column Salmon header, identical gene ID and gene order at every row, and exactly 13,151,701 genes.

It produces `Gene_TPM.tsv` and `Gene_NumReads.tsv`. Each matrix has 13,151,701 gene rows across 60 samples: 13,151,702 lines including the header and 61 columns including `Gene`. These matrices are the formal community-gene abundance source for later functional-abundance aggregation.

### Slurm resources

| Step | CPUs | Memory | Wall time | Array |
| --- | ---: | ---: | ---: | --- |
| Per-sample Prodigal | 1 | 4G | 3 hours | `1-60%20` |
| Merge filtered genes | 1 | 8G | 4 hours | — |
| MMseqs2 clustering | 16 | 450G | 48 hours | — |
| NR protein extraction | 4 | 64G | 12 hours | — |
| Salmon index | 8 | 200G | 12 hours | — |
| Salmon quantification | 4 | 32G | 3 hours | `1-60%8` |
| Merge Salmon matrices | 1 | 16G | 12 hours | — |

The archived scripts also contain production partition, account, QoS, and node exclusions; the portable references omit these site-specific directives.

### Output

- Per-sample filtered nucleotide genes, matching proteins, GFF, and QC summaries
- `all_genes.min100.ffn`
- `NR_gene_catalog.ffn`
- `NR_gene_clusters.tsv`
- `NR_gene_catalog.faa`
- Salmon index and 60 per-sample `quant.sf` results
- `Gene_TPM.tsv`
- `Gene_NumReads.tsv`

### Quality control

The per-sample workflow requires non-zero retained genes and matching filtered FFN/FAA counts. Merging requires 60 files and 28,098,350 genes. MMseqs2 requires 28,098,350 cluster-membership rows and a valid representative count. NR protein extraction requires exactly 13,151,701 proteins. Salmon indexing and quantification enforce the 13,151,701-gene reference, and matrix merging checks headers, gene identities, gene order, row count, and sample count.

### Verified results

| Metric | Verified value |
| --- | ---: |
| Raw predicted genes | 29,122,712 |
| Genes at least 100 bp | 28,098,350 |
| Retained proteins | 28,098,350 |
| Representative NR genes | 13,151,701 |
| Reduction | 53.1940% |
| Cluster-membership rows | 28,098,350 |
| NR proteins | 13,151,701 |
| Salmon samples | 60 |
| Mean mapping rate | 89.977833% |
| Mapping-rate range | 87.84–91.93% |

### Frozen methodological decisions

The use of 60 individual assemblies rather than a co-assembly; sample-prefixed contig IDs; Prodigal `-p meta`; the 100-bp nucleotide CDS filter; exact protein-ID matching; 60-file merge; nucleotide MMseqs2 clustering settings; exact NR protein extraction; Salmon index and quantification settings; expected counts; validation logic; and final matrix semantics are frozen.

## 11B — MAG-specific gene catalog

### Purpose

Predict genes independently in the 374 Stage 08 dRep representative MAGs, merge their nucleotide and protein sequences, and retain an explicit gene-to-MAG mapping.

This branch is not the 11A community NR catalog. It performs no MMseqs2 clustering and no Salmon quantification.

### Input

- Exactly 374 Stage 08 dRep representative MAGs
- An ordered `MAG_LIST` containing those representatives

The archive does not provide a supported ordered 374-MAG manifest, so the portable workflow requires `MAG_LIST` and does not invent an order.

### Gene prediction

Prodigal 2.6.3 runs separately for every MAG. Each contig identifier is prefixed with its MAG name. The formal mode is `-p single`, producing FFN, FAA, and GFF files.

The production command has no explicit translation-table override. Not captured in the archived production record. No partial-gene filter is applied.

### Catalog merging

The merge processes exactly 374 MAGs. For every MAG it requires non-empty FFN and FAA files, equal gene/protein counts, and identical ordered gene IDs. It then concatenates nucleotide genes and proteins and creates a per-MAG summary.

### Gene-to-MAG mapping

Every nucleotide gene header contributes one `Gene` to `MAG` record. `MAG_gene_to_MAG.tsv` has 688,771 data rows representing 374 unique MAGs.

### Slurm resources

| Step | CPUs | Memory | Wall time | Array |
| --- | ---: | ---: | ---: | --- |
| Per-MAG Prodigal | 1 | 4G | 1 hour | `1-374%40` |
| Merge MAG genes | 1 | 8G | 4 hours | — |

The archived scripts also contain production partition, account, QoS, and node exclusions; the portable references omit these site-specific directives.

### Output

- Per-MAG FFN, FAA, GFF, and QC summaries
- `MAG_gene_catalog.ffn`
- `MAG_gene_catalog.faa`
- `MAG_gene_to_MAG.tsv`
- `MAG_prodigal_summary.tsv`

### Quality control

Per-MAG prediction must produce more than zero genes and equal FFN/FAA counts. The merge validates both files and exact gene-ID equality for every MAG, then requires 374 summary rows and equality among total genes, merged FFN records, merged FAA records, and gene-to-MAG rows.

### Verified results

- Representative MAGs: 374
- Nucleotide genes: 688,771
- Proteins: 688,771
- `MAG_gene_to_MAG.tsv` data rows: 688,771
- Unique MAGs in the mapping: 374

### Frozen methodological decisions

The 374-representative input set; MAG-prefixed contig IDs; Prodigal `-p single`; absence of an explicit translation-table override; absence of length, partial-gene, MMseqs2, and Salmon filtering or processing; per-MAG FFN/FAA validation; exact gene-ID equality; merge counts; gene-to-MAG semantics; and outputs are frozen.
