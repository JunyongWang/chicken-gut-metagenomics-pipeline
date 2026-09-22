# Stage 07 — CheckM2 MAG quality assessment

## Purpose

Estimate completeness and contamination for all Stage 06 refined candidates and define the quality-controlled input set for dereplication.

## Input

- Exactly 2,782 Stage 06 refined candidate MAGs with extension `fa`
- CheckM2 UniRef100 KO database file `uniref100.KO.1.dmnd`

## Software and version

- CheckM2 1.1.0
- Database release or acquisition date: Not captured in the archived production record.

## Parameters

The formal command is `checkm2 predict` with `--threads 4` and `-x fa`. The database is supplied through `--database_path`.

## Slurm resources

- Production site settings: partition `Cnode_all`, account `wenswjy`, QoS `normal`, with archived node exclusions
- 1 node, 1 task, 4 CPUs, 24G memory, 24-hour wall time

## Execution

Run `scripts/07_checkm2/checkm2_all.sh` with `STAGE_DIR`, `CONDA_SH`, and `CHECKM2_DB` set. `MAG_DIR` and `CHECKM2_OUT` may override the default stage-relative input and output locations.

## Output

- CheckM2 output directory containing `quality_report.tsv`
- GNU time log and CheckM2 log
- `.checkm2.done`

## Quality control

The script refuses to overwrite an existing output directory, requires a non-empty `quality_report.tsv`, and requires exactly 2,782 result rows before writing `.checkm2.done`.

The full production `quality_report.tsv` was not retained in the archived handoff. The supplied threshold-count table is the verified frozen project record.

## Verified results

| Quality subset | MAGs |
| --- | ---: |
| Refined candidates assessed | 2,782 |
| Completeness `>= 50%`, contamination `<= 10%` | 2,672 |
| Completeness `>= 80%`, contamination `<= 10%` | 1,683 |
| Completeness `>= 90%`, contamination `<= 5%` | 926 |

## Frozen methodological decisions

CheckM2 is run once across all 2,782 candidates with four threads and the UniRef100 KO database. The formal Stage 08 input is strictly the 2,672-MAG 50/10 subset; the 80/10 and 90/5 subsets do not replace it.
