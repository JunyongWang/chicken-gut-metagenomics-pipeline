# Stage 09 — GTDB-Tk MAG taxonomy

## Purpose

Classify the 374 dereplicated representative MAGs against GTDB release R226.

## Input

- Exactly 374 Stage 08 representative MAGs with extension `fa`
- GTDB reference data release R226 supplied through `GTDBTK_DATA_PATH`

The production staging directory contained the verified 374 dRep representatives. The exact historical staging or symlink-creation command was not captured in the archived production record. The representative set is a verified computational decision; only its file-staging mechanics are unarchived.

## Software and version

- GTDB-Tk 2.6.1
- GTDB release R226

## Parameters

```text
gtdbtk classify_wf --extension fa --cpus 8 --pplacer_cpus 4
```

## Slurm resources

- Production site settings: partition `Cnode_all`, account `wenswjy`, QoS `normal`, with archived node exclusions
- 1 node, 1 task, 8 CPUs, 200G memory, 48-hour wall time

## Execution

Run `scripts/09_gtdbtk/gtdbtk_all.sh` with `STAGE_DIR`, `CONDA_SH`, and `GTDBTK_DATA_PATH` set. `MAG_DIR` and `GTDBTK_OUT` may override the stage-relative locations.

## Output

- GTDB-Tk R226 classification directory
- Bacterial summary `gtdbtk.bac120.summary.tsv`
- GNU time log and GTDB-Tk log
- `.gtdbtk.done`

## Quality control

The portable script accepts regular `.fa` files and symbolic links to `.fa` files, requires exactly 374 input MAGs, and refuses to overwrite an existing output directory. The archived final bacterial summary was checked independently for row count and non-empty genus and species rank assignments.

## Verified results

| Assignment level | MAGs |
| --- | ---: |
| Bacterial summary rows | 374 |
| Genus assigned | 372 |
| Species assigned | 338 |

## Frozen methodological decisions

The 374 representative input set, GTDB R226, `classify_wf`, `fa` extension, eight total CPUs, and four pplacer CPUs are frozen. The formal CPU allocation is eight, not sixteen.
