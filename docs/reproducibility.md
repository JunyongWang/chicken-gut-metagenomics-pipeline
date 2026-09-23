# Reproducibility

## Scope

Stages 01–12 are represented by portable reference scripts derived from archived production scripts without changing analytical flags or frozen biological rules.

## Evidence and controls

- The ordered sample list is versioned at `config/samples.txt`.
- Production paths are documented for provenance while portable scripts use configurable variables.
- Site account, partition, QoS, and node exclusions are not embedded in portable scripts.
- Completion markers are written only after stage-specific integrity checks.
- QC helper scripts are retained beside their corresponding stage scripts.
- Archived QC tables are used to verify aggregate results but are not committed.
- Stages 06–10 retain formal sample/MAG counts, checkpoint logic, thresholds, thread allocations, Slurm resources, and output-shape validations.
- Stage 11 keeps community NR and MAG-specific gene catalogs separate and preserves their different Prodigal modes, filtering rules, clustering, and abundance semantics.
- Stage 12 preserves separate NR and MAG eggNOG/dbCAN branches, the historically mixed eggNOG NR execution provenance, the exact dbCAN method argument, `#ofTools >= 2` recommendation rule, CAZy parent-family parsing, SLH handling, and MAG-weighted CAZyme formula.
- Missing submission-time array directives for selected Stage 12 scripts are explicitly left undocumented rather than reconstructed.
- Historical dbCAN wrong-method outputs are excluded from the formal workflow.
- Personal HPC paths and private database source locations are replaced by explicit variables such as `WORK_ROOT`, `STAGE_DIR`, `EGGNOG_DATA`, and `DBCAN_DB`.

Stages 01 and 02 rely on `SLURM_ARRAY_TASK_ID`; their original submission-time array ranges and concurrency were not captured and are not reconstructed. The same principle is applied to Stage 12 scripts whose archived source lacks an array directive.
