# Stage 13 — KEGG Orthology abundance scripts

Portable references for the verified production Stage 13 workflow.

- `aggregate_NR_KO.sh` and `aggregate_NR_KO.py`: community NR KO abundance from Stage 12A eggNOG annotations plus Stage 11A gene TPM/NumReads.
- `build_MAG_KO_matrix.py`: 374-MAG × KO gene-count matrix from Stage 12A MAG eggNOG annotations and the Stage 11B gene-to-MAG map.
- `build_MAG_weighted_KO.py`: MAG-abundance-weighted KO TPM using the Stage 10 MAG TPM matrix.

Only the 13A community aggregation had a formal Slurm wrapper in the archived production snapshot (1 CPU, 32G, 12 h). No formal Slurm wrappers were retained for 13B or 13C, so public documentation does not reconstruct resources for those steps.

The Python scripts accept environment-variable path overrides while preserving production defaults and all frozen parsing, count, sample-order, and conservation checks. Stage 13 does not perform a new eggNOG search and does not aggregate KOs to KEGG pathways or modules.
