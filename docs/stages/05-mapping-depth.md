# Stage 05 — read mapping and contig depth

## Purpose

Build a per-sample Bowtie2 index, map each sample's host-removed reads to its own assembly, create a validated coordinate-sorted BAM, and generate a MetaBAT2-compatible mother depth table.

## Input

- Stage 02 dehost paired reads
- Stage 04 standardized `<sample>.final.contigs.fa`
- Ordered `config/samples.txt`

Production used project-specific stage paths. The portable script exposes `WORK_ROOT`, `DEHOST_ROOT`, `ASSEMBLY_ROOT`, and `STAGE_DIR`.

## Software and version

- Bowtie2 2.5.5
- samtools: Not captured in the archived production script.
- `jgi_summarize_bam_contig_depths`: Not captured in the archived production script.

## Parameters

| Step | Production setting |
| --- | --- |
| Index | Build per sample from its assembly |
| Bowtie2 | `--end-to-end --sensitive -p 6` |
| samtools sort | `-@ 1 -m 1G` |
| BAM index/flagstat | `-@ 7` |
| Depth identity | `--percentIdentity 97` |
| Depth reference | `--referenceFasta <assembly>` |
| Contig-length filter | None in the mother table |

## Slurm resources

- Production site settings: partition `Cnode_all`, account `wenswjy`, QoS `normal`, excluded nodes `cnode1057,cnode1015,cnode1006,cnode1008,cnode1012`
- 1 node, 1 task, 8 CPUs, 12G memory, 4-hour wall time
- Array: `1-60%10`

## Execution

```bash
bowtie2-build \
    --threads "$SLURM_CPUS_PER_TASK" \
    "$CONTIGS" "$INDEX"

bowtie2 \
    --end-to-end --sensitive \
    -x "$INDEX" -1 "$R1" -2 "$R2" -p 6 \
| samtools sort \
    -@ 1 -m 1G -T "$TMP_PREFIX" \
    -o "$BAM" -

jgi_summarize_bam_contig_depths \
    --outputDepth "$DEPTH" \
    --percentIdentity 97 \
    --referenceFasta "$CONTIGS" \
    "$BAM"
```

No intermediate SAM is written. The temporary index is removed only after successful depth generation because it can be rebuilt from retained contigs.

## Output

- Coordinate-sorted BAM and BAI
- Bowtie2 log and flagstat
- `<sample>.contig_depth.tsv` and depth log
- GNU time log
- `.mapping_depth.done`

## Quality control

The workflow runs `samtools quickcheck`, verifies BAI and flagstat, requires a non-empty depth table, and checks that depth data rows equal assembly FASTA records. A mismatch stops the task. The marker is written only after all checks.

The archived QC table contains 60 samples:

| Metric | Mean | Range |
| --- | ---: | ---: |
| Overall alignment | 82.9513% | 77.82–90.13% |
| Properly paired | 77.2770% | 72.13–85.33% |

## Verified results

All 60 records have `Depth_complete = YES`; assembly contig and depth-row counts match for every sample. Mean runtime was 29.017 minutes (17.113–64.367), and mean maximum resident memory was 1.394 GiB (1.170–3.432).

## Frozen methodological decisions

Per-sample indexing, mapping mode and threads, sort settings, BAM validation/indexing, 97% identity depth calculation, no mother-table contig filter, row-count equality, and temporary-index cleanup are frozen.
