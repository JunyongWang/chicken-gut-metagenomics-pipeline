# Reproducibility

## Scope

Stages 01–05 are represented by portable reference scripts derived from the archived production scripts without changing analytical flags.

## Evidence and controls

- The ordered sample list is versioned at `config/samples.txt`.
- Production paths are documented for provenance while portable scripts use configurable variables.
- Site account, partition, QoS, and node exclusions are not embedded in portable scripts.
- Completion markers are written only after stage-specific integrity checks.
- QC helper scripts are retained beside their corresponding stage scripts.
- The archived QC tables were used to verify aggregate results but are not committed.

Stages 01 and 02 rely on `SLURM_ARRAY_TASK_ID`; their original submission-time array ranges and concurrency were not captured and are not reconstructed.
