# Stage 13 — KEGG Orthology abundance

Stage 13 converts the Stage 12A eggNOG `KEGG_ko` assignments into three verified KO-level products: community NR gene abundance, a MAG × KO gene-count matrix, and MAG-abundance-weighted KO TPM. It performs no new eggNOG search and no KEGG pathway or module aggregation.

## 13A — Community NR KO abundance

### Purpose

Aggregate Stage 11A community gene TPM and NumReads into KEGG Orthology abundance using the final Stage 12A NR eggNOG annotations.

### Input

- Stage 12A final NR eggNOG annotation table with 10,813,185 annotated gene rows
- Stage 11A `Gene_TPM.tsv`
- Stage 11A `Gene_NumReads.tsv`
- The fixed 60-sample order M1–M61 excluding M23

### KO parsing and abundance rule

The production parser reads the eggNOG `KEGG_ko` column. Valid assignments must match `ko:K#####`; multiple assignments are comma-separated. Duplicate KO assignments within one gene are collapsed before aggregation.

A gene with multiple distinct KOs contributes its **full** TPM or NumReads value to every distinct KO assigned to that gene. Abundance is not divided by the number of KOs.

### Slurm resources

- 1 node, 1 task, 1 CPU
- 32G memory
- 12-hour wall time

The portable wrapper omits production-site partition, account, QoS, node exclusions, username-specific Python path, and other site-specific settings.

### Execution

Run `scripts/13_function_abundance/aggregate_NR_KO.sh`. The wrapper exposes annotation, abundance-matrix, output, stage, and Python paths through environment variables while retaining the formal resource request and aggregation semantics.

### Output

- `NR_KO_gene_map.tsv`
- `NR_KO_TPM.tsv`
- `NR_KO_NumReads.tsv`
- `NR_KO_abundance_QC.tsv`
- `NR_KO_summary.tsv`
- `.ko_abundance.done`

Each KO abundance matrix contains 7,765 KO rows × 60 samples: 7,766 lines including the header and 61 columns including `KO`.

### Quality control

The script requires exactly 10,813,185 annotation rows and exactly 13,151,701 rows in each Stage 11A abundance matrix. The sample order must match the frozen 60-sample order. Every KO-bearing gene must be present in both source matrices. KO-expanded totals are independently reconstructed from gene abundance × number of distinct KO assignments and compared with the observed KO matrix totals using `math.isclose` with `rel_tol=1e-10` and `abs_tol=1e-5`.

### Verified results

| Metric | Verified value |
| --- | ---: |
| Annotated NR genes | 10,813,185 |
| Genes with KO | 5,995,496 |
| Multi-KO genes | 528,292 |
| Unique KOs | 7,765 |
| Gene-KO links | 6,614,347 |
| Duplicate KO assignments within a gene | 0 |
| TPM matrix rows matched to KO genes | 5,995,496 |
| NumReads matrix rows matched to KO genes | 5,995,496 |

### Frozen methodological decisions

The eggNOG `KEGG_ko` source column, strict `ko:K#####` token form, duplicate-within-gene collapse, full abundance to every distinct KO, 60-sample order, expected row counts, and conservation checks are frozen.

## 13B — MAG × KO gene-count matrix

### Purpose

Link Stage 12A MAG eggNOG KO assignments back to the 374 representative MAGs and construct a MAG × KO gene-count matrix.

### Input

- Stage 12A final MAG eggNOG annotation table
- Stage 11B `MAG_gene_to_MAG.tsv`

### KO parsing and counting rule

The script reads `KEGG_ko` assignments matching `ko:K#####`. A gene assigned to multiple distinct KOs contributes one gene-KO link to every distinct KO. Duplicate KO assignments within one gene are collapsed; the verified production data contained zero such duplicates.

### Slurm resources

No formal Slurm wrapper for 13B was retained in the archived production snapshot. Resources are therefore not reconstructed.

### Execution

Run `scripts/13_function_abundance/build_MAG_KO_matrix.py`. `MAG_EGGNOG_ANNOTATIONS`, `GENE_TO_MAG`, and `MAG_KO_OUT` may override the production-relative paths without changing the counting logic.

### Output

- `MAG_KO_gene_map.tsv`
- `MAG_KO_gene_count_matrix.tsv`
- `MAG_KO_gene_counts.tsv`
- `MAG_KO_MAG_summary.tsv`
- `MAG_KO_matrix_summary.tsv`

The formal matrix contains 374 MAG rows × 5,646 KO columns: 375 lines including the header and 5,647 columns including `MAG`.

### Quality control

The script requires exactly 688,771 genes in the gene-to-MAG map, 374 unique MAGs, 622,522 eggNOG annotation rows, 369,671 KO-bearing genes, 30,225 multi-KO genes, 5,646 unique KOs, and 404,993 gene-KO links. Every annotated gene must exist in the gene-to-MAG map. Matrix total counts must equal the independently counted 404,993 links.

### Verified results

| Metric | Verified value |
| --- | ---: |
| Input MAG genes | 688,771 |
| eggNOG annotated genes | 622,522 |
| MAGs | 374 |
| Genes with KO | 369,671 |
| Multi-KO genes | 30,225 |
| Unique KOs | 5,646 |
| Gene-KO links | 404,993 |
| Matrix total counts | 404,993 |
| Duplicate KO assignments within a gene | 0 |

### Frozen methodological decisions

The 374 representative MAG set, Stage 11B gene-to-MAG mapping, strict KO token parser, one count per distinct gene-KO assignment, exact expected counts, and matrix semantics are frozen.

## 13C — MAG abundance-weighted KO TPM

### Purpose

Weight each MAG's KO gene content by the Stage 10 CoverM genome TPM to estimate MAG-abundance-weighted KO functional potential across 60 samples.

### Input

- Stage 10 `MAG_tpm.tsv`
- Stage 13B `MAG_KO_gene_count_matrix.tsv`

### Formula

```text
Weighted_KO_TPM(KO, sample)
= sum_MAG(KO_gene_count × MAG_TPM)
```

This quantity is **not equivalent** to the Stage 13A Salmon gene-level KO TPM matrix. Stage 13A aggregates directly quantified community genes; Stage 13C weights MAG gene content by MAG abundance.

### Slurm resources

No formal Slurm wrapper for 13C was retained in the archived production snapshot. Resources are therefore not reconstructed.

### Execution

Run `scripts/13_function_abundance/build_MAG_weighted_KO.py`. `MAG_TPM`, `KO_MATRIX`, and `MAG_WEIGHTED_KO_OUT` expose portable input/output locations.

### Output

- `MAG_weighted_KO_TPM.tsv`
- `MAG_weighted_KO_QC.tsv`
- `MAG_weighted_KO_summary.tsv`

The weighted matrix contains 5,646 KO rows × 60 samples: 5,647 lines including the header and 61 columns including `KO`.

### Quality control

The script requires exactly 374 MAGs and 5,646 KO columns, identical MAG sets between the Stage 10 TPM matrix and Stage 13B KO matrix, the frozen 60-sample order, non-negative TPM/count values, and unique MAG/KO identifiers.

For every sample it independently calculates `MAG_TPM × total KO-link count per MAG` and compares this expected total with the sum of the weighted KO matrix using `rel_tol=1e-12` and `abs_tol=1e-5`.

### Verified results

- MAGs: 374
- KOs: 5,646
- Samples: 60
- MAG TPM sum range: 999999.461291–1000000.736210
- Maximum conservation error: 0.000041484833

### Frozen methodological decisions

The Stage 10 genome TPM weight, Stage 13B MAG × KO gene-count matrix, `sum_MAG(KO_gene_count × MAG_TPM)` formula, 374-MAG/60-sample dimensions, and conservation check are frozen.

## Scope boundary

Stage 13 ends at KO-level abundance and MAG-weighted KO summaries. The archived formal workflow contains no KO-to-pathway/module aggregation and no new pathway enrichment step. CARD/ARG analysis was not performed and is not part of this stage.
