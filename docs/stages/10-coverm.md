# Stage 10 — CoverM MAG abundance

## Purpose

Build a minimap2-sr database from the 374 representative MAGs, quantify each sample's host-removed reads against it, merge four abundance metrics, and assemble a MAG metadata catalog.

## Input

- Exactly 374 Stage 08 representative MAGs
- Stage 02 host-removed paired reads for 60 ordered samples
- Stage 07 CheckM2 report and Stage 09 GTDB-Tk bacterial summary for catalog integration

The production database-staging directory contained the verified 374 dRep representatives. The exact historical staging or symlink-creation command was not captured in the archived production record. The reference set is verified; only the mechanics used to populate its staging directory are unarchived.

## Software and version

- CoverM 0.8.0
- minimap2 2.31-r1302

## Parameters

Database creation uses `coverm makedb -d <374 MAGs> -x fa -p minimap2-sr -t 8`.

Per-sample quantification uses:

```text
-p minimap2-sr --minimap2-reference-is-index -s '~' --threads 4
--min-read-percent-identity 95 --min-read-aligned-percent 75
--methods mean covered_fraction relative_abundance tpm
```

## Slurm resources

| Job | CPUs | Memory | Wall time | Array |
| --- | ---: | ---: | ---: | --- |
| Database creation | 8 | 16G | 4 hours | — |
| Per-sample quantification | 4 | 12G | 3 hours | `1-60%10` |

Both archived scripts used production partition `Cnode_all`, account `wenswjy`, QoS `normal`, and recorded node exclusions.

## Execution

Run `scripts/10_coverm/coverm_makedb.sh`, followed by `scripts/10_coverm/coverm_array.sh`. Then run `scripts/10_coverm/merge_coverm.py` and `scripts/10_coverm/make_MAG_catalog.py`.

The portable scripts expose stage, work, sample-list, conda, database/index, report, summary, and catalog-output locations through clearly named variables. Analytical settings and validation counts remain unchanged.

## Output

- minimap2-sr CoverM database and `.makedb.done`
- Per-sample CoverM table, log, time log, and `.coverm.done`
- `MAG_mean_coverage.tsv`
- `MAG_covered_fraction.tsv`
- `MAG_relative_abundance.tsv`
- `MAG_tpm.tsv`
- `mapping_summary.tsv`
- `MAG_catalog_metadata.tsv` integrating CheckM2, GTDB-Tk, and CoverM summaries

## Quality control

Database creation accepts regular `.fa` files and symbolic links to `.fa` files and requires exactly 374 input MAGs. Each sample table must have 376 lines: one header, 374 MAG rows, and one `unmapped` row. The merge script requires exactly 60 samples, 374 unique MAGs per sample, one unmapped row, five columns, and identical MAG sets across all samples.

Each merged matrix is 374 MAGs by 60 samples: 375 rows including the header and 61 columns including `Genome`. Catalog creation requires 60 matrix columns, 374 GTDB genomes, and matching CheckM2 and CoverM records.

## Verified results

- Samples: 60
- Representative MAGs: 374
- Mean mapped percentage: 59.157301%
- Mapped percentage range: 52.419437–67.811745%

## Frozen methodological decisions

The 374-MAG reference set, minimap2-sr preset, indexed-reference mode, `~` separator, four quantification threads, 95% read identity, 75% aligned-read percentage, four reported methods, per-sample line-count check, cross-sample MAG-set checks, matrix dimensions, and catalog integration are frozen.
