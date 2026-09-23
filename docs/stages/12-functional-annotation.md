# Stage 12 — Functional annotation and CAZyme analysis

Stage 12 contains two linked but distinct functional workflows. Stage 12A annotates the community NR and MAG-specific protein catalogs with eggNOG-mapper. Stage 12B annotates CAZymes with dbCAN and derives community-gene and MAG-level CAZyme family summaries. KEGG Orthology abundance is handled separately in Stage 13.

## 12A — eggNOG functional annotation

### Software and database

- eggNOG-mapper 2.1.15
- eggNOG database 5.0.2
- protein input with DIAMOND search

The archived production commands do not apply `-d bact` or another bacteria-only taxonomic scope. No such restriction is added to the portable reference scripts.

### 12A-1 — MAG gene catalog

#### Purpose and input

Annotate the 688,771 proteins from the Stage 11B MAG-specific gene catalog. The formal run used seven protein chunks: chunks 001–006 contained 100,000 proteins each and chunk 007 contained 88,771 proteins.

The archived production record contains the seven-chunk annotation workflow but not the exact historical command that created the eggNOG MAG chunk directory. The portable annotation script therefore accepts an externally staged chunk directory and chunk manifest rather than inventing that command.

#### Parameters and execution

`eggnog_MAG_array.sh` runs `emapper.py` with:

```text
--itype proteins
-m diamond
--cpu 4
```

The formal Slurm request was 4 CPUs, 24G memory, and 24 hours. The archived script does not contain its submission-time array directive or concurrency, so those values are not reconstructed.

`merge_eggnog_MAG.sh` merges all seven completed chunks with 1 CPU, 8G memory, and a 2-hour wall time. It verifies chunk completion markers, non-empty annotation and seed-ortholog tables, the total input count, and merged row counts.

#### Output and verified results

Primary outputs are:

- `MAG_eggnog_annotations.tsv`
- `MAG_eggnog_seed_orthologs.tsv`
- `MAG_eggnog_summary.tsv`

| Metric | Verified value |
| --- | ---: |
| Input proteins | 688,771 |
| Annotated proteins | 622,522 |
| Seed-ortholog rows | 622,524 |
| Annotation rate | 90.3816% |

Per-chunk completion is recorded by `.eggnog.done`; the merged result uses `.merge_eggnog_MAG.done`.

### 12A-2 — community NR gene catalog

#### Purpose and input

Annotate the 13,151,701 proteins from the Stage 11A community NR catalog. `split_eggnog_NR.sh` divides the catalog into 132 chunks: chunks 001–131 contain 100,000 proteins each and chunk 132 contains 51,701 proteins. The split job used 1 CPU, 8G memory, and 4 hours.

#### Production execution history

The final production result has mixed execution provenance and should not be simplified into a single hypothetical run. Twelve chunks were completed by the original full-emapper workflow:

```text
001 002 003 004 005 006 008 011 012 013 014 015
```

`eggnog_NR_array.sh` is the archived full annotation script. It used 4 CPUs, 24G memory, 24 hours, protein input, and DIAMOND mode. Its submission-time array directive is not present in the archived script.

The other 120 chunks used two stages. Stage 1 used `eggnog_NR_stage1_search.sh` with 8 CPUs, 24G memory, 24 hours, DIAMOND mode, `--no_annot`, and node-local temporary storage. A 40G retry variant with the same analytical command is preserved as `eggnog_NR_stage1_retry40G.sh`; the archive does not identify the exact chunks that required that retry.

Stage 2 used `eggnog_NR_stage2_batch_array.sh`. It processes 12 manifests of 10 chunks each, merges the Stage 1 seed-ortholog tables, checks unique query IDs, and runs:

```text
-m no_search
--annotate_hits_table <merged seed orthologs>
--dbmem
```

The formal Stage 2 request was 1 CPU, 64G memory, and 6 hours. Its submission-time array directive or concurrency is not embedded in the archived script and is not reconstructed.
The Stage 2 script expects 12 `batch_XX.txt` manifests with 10 chunks each. The exact historical command used to generate those manifests was not retained, so the public workflow documents the required manifest structure without inventing a generator.

`eggnog_NR_final_merge.sh` used 1 CPU, 32G memory, and 6 hours. It combines the 12 original full-emapper chunks with the 120 Stage 2 chunks using the archived source-selection logic and reconstructs seed-ortholog output in natural 001–132 chunk order.

#### Output and verified results

Primary final outputs are:

- `NR_eggnog_annotations.tsv`
- `NR_eggnog_seed_orthologs.tsv`
- `NR_eggnog_summary.tsv`

| Metric | Verified value |
| --- | ---: |
| Input proteins | 13,151,701 |
| Seed-ortholog queries | 10,813,218 |
| Annotated queries | 10,813,185 |
| Seed rate | 82.2192% |
| Annotation rate | 82.2189% |

Stage 1 uses `.search.done`, Stage 2 uses `.annotation.done`, and the final NR merge uses `.merge.done`.

### Frozen eggNOG decisions

The two Stage 11 protein catalogs remain separate; eggNOG is run on proteins; DIAMOND search is used without a bacteria-only taxonomic restriction; the verified chunk counts and mixed NR execution provenance are retained; and the final merge logic, expected counts, and QC checks are frozen.

## 12B — dbCAN CAZyme analysis

### Software and database

- dbCAN 5.2.9
- protein mode
- required database files: `CAZy.dmnd`, `dbCAN.hmm`, `dbCAN-sub.hmm`, and `fam-substrate-mapping.tsv`

The formal method argument is exactly:

```text
--methods diamond,hmm,dbCANsub
```

It is passed as one argument. Historical outputs produced with an incorrect method invocation are not part of the formal workflow and are not represented in this repository.

A recommended CAZyme is defined from dbCAN V5 `overview.tsv` as `#ofTools >= 2` (column 6).

### 12B-1 — MAG dbCAN annotation

`split_dbcan_MAG.sh` splits the 688,771 Stage 11B proteins into seven chunks. `dbcan_MAG_array.sh` runs dbCAN with 4 CPUs, 16G memory, and a 6-hour wall time. The archived formal script does not contain its submission-time array directive, so concurrency is not reconstructed.

`merge_dbcan_MAG.sh` combines the seven chunk-level `overview.tsv` files and retains recommended rows with `#ofTools >= 2`.

| Metric | Verified value |
| --- | ---: |
| Input proteins | 688,771 |
| Genes in overview | 39,129 |
| Recommended CAZyme genes | 22,464 |
| Overview rate | 5.6810% |
| Recommended rate | 3.2615% |

### 12B-2 — community NR dbCAN annotation

The NR workflow reuses the 132 Stage 12A NR chunks. `dbcan_NR_array.sh` uses 4 CPUs, 16G memory, 6 hours, and the formal array `1-132%20`.

`merge_dbcan_NR.sh` checks all 132 completed chunks, merges overview rows, filters recommended rows with `#ofTools >= 2`, verifies unique gene IDs, and writes the final summary.

| Metric | Verified value |
| --- | ---: |
| Input proteins | 13,151,701 |
| Genes in overview | 425,888 |
| Recommended CAZyme genes | 267,092 |
| Overview rate | 3.2383% |
| Recommended rate | 2.0309% |

### 12B-3 — community NR CAZyme-family abundance

`aggregate_dbcan_NR_family.sh` and `aggregate_dbcan_NR_family.py` combine the 267,092 recommended NR CAZyme annotations with the Stage 11A `Gene_TPM.tsv` and `Gene_NumReads.tsv` matrices. The Slurm wrapper uses 1 CPU, 8G memory, and 12 hours.

Numbered parent families are normalized within AA, CBM, CE, GH, GT, and PL. Repeated domains from the same parent family within one gene are counted once. If one gene contains multiple distinct parent families, its full TPM or NumReads value contributes to every distinct family; abundance is not divided by the number of families. `SLH` is excluded from the numbered-family matrices, while numbered partner families on SLH-containing genes are retained.

Verified structure:

| Metric | Verified value |
| --- | ---: |
| Recommended genes | 267,092 |
| Genes with a numbered family | 267,091 |
| Parent families | 291 |
| Gene-family links | 275,206 |
| Multi-parent genes | 7,885 |
| SLH-containing genes | 31 |
| SLH tokens | 37 |
| SLH-only genes | 1 |
| Samples | 60 |

Primary outputs include `NR_cazyme_gene_family_map.tsv`, family gene counts, SLH features, family TPM and NumReads matrices, QC, and summary tables.

### 12B-4 — MAG × CAZyme family gene-count matrix

`build_MAG_cazyme_matrix.py` combines the Stage 11B gene-to-MAG mapping with the 22,464 recommended MAG CAZyme genes. No formal Slurm wrapper is present in the archived production snapshot, so Slurm resources are not reconstructed.

The same numbered parent-family logic is used. Repeated families within one gene count once, distinct families each receive one link, and `SLH` is excluded. The observed special token `CBM35inCE17` is normalized to `CBM35` exactly as in the production script.

| Metric | Verified value |
| --- | ---: |
| MAGs | 374 |
| Recommended genes | 22,464 |
| Genes with numbered family | 22,464 |
| Parent families | 266 |
| Gene-family links | 24,137 |
| Multi-parent genes | 1,608 |
| SLH-containing genes | 4 |
| SLH tokens | 6 |
| SLH-only genes | 0 |
| Matrix total | 24,137 |

### 12B-5 — MAG abundance-weighted CAZyme TPM

`build_MAG_weighted_cazyme.py` combines the Stage 10 MAG TPM matrix with the Stage 12B-4 MAG × CAZyme family gene-count matrix. No formal Slurm wrapper is present in the archived production snapshot.

For family \(f\) and sample \(s\):

```text
Weighted_CAZyme_TPM(f,s) = sum_MAG(CAZyme_family_gene_count * MAG_TPM)
```

This is a MAG-abundance-weighted functional potential. It is not equivalent to the Stage 11A Salmon gene-level CAZyme TPM matrix.

Verified result:

- 374 MAGs
- 266 CAZyme parent families
- 60 samples
- 266 family rows × 60 samples
- 267 lines including header
- 61 columns including `Family`
- MAG TPM sums: 999999.461291–1000000.736210
- maximum conservation error: 0.000000178814

### Frozen dbCAN and CAZyme decisions

The single-argument dbCAN method syntax; `#ofTools >= 2` recommendation rule; 132-chunk NR execution; parent-family normalization; within-gene family de-duplication; full abundance contribution to every distinct family; SLH exclusion; `CBM35inCE17 -> CBM35`; MAG × family count semantics; and MAG-TPM weighting formula are frozen.
