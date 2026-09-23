# Reproducibility

## Scope

Stages 01–11 are represented by portable reference scripts derived from the archived production scripts without changing analytical flags.

## Evidence and controls

- The ordered sample list is versioned at `config/samples.txt`.
- Production paths are documented for provenance while portable scripts use configurable variables.
- Site account, partition, QoS, and node exclusions are not embedded in portable scripts.
- Completion markers are written only after stage-specific integrity checks.
- QC helper scripts are retained beside their corresponding stage scripts.
- The archived QC tables were used to verify aggregate results but are not committed.
- Stages 06–10 retain formal sample/MAG counts, checkpoint logic, thresholds, thread allocations, Slurm resources, and output-shape validations.
- Personal HPC paths are replaced by explicit variables; production site directives remain documented on the stage pages.
- Stage 11 keeps the community NR and MAG-specific catalogs in separate script directories and documents their different inputs, Prodigal modes, filtering rules, and output semantics.
- Stage 11A reuses `config/samples.txt`; Stage 11B requires a user-supplied `MAG_LIST` because an authoritative ordered 374-MAG manifest was not archived.

Stages 01 and 02 rely on `SLURM_ARRAY_TASK_ID`; their original submission-time array ranges and concurrency were not captured and are not reconstructed.
