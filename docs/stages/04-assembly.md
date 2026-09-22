# Stage 04 — MEGAHIT assembly

## Purpose

Assemble each sample independently from host-removed paired reads and generate standardized contig and assembly-QC outputs.

## Input

- Stage 02 dehost paired reads
- Ordered `config/samples.txt`

## Software and version

- MEGAHIT 1.2.9, explicitly recorded in the production script
- seqkit: Not captured in the archived production script.
- Python interpreter: Not captured in the archived production script.

## Parameters

| Setting | Production value |
| --- | --- |
| Assembly unit | Individual sample |
| k-mer strategy/list | `--kmin-1pass --k-list 27,37,47,57,67,77,87` |
| Minimum count | `--min-count 2` |
| Minimum contig | `--min-contig-len 500` |
| Threads | `-t 16` via `SLURM_CPUS_PER_TASK` |
| MEGAHIT memory | `-m 24000000000` bytes |

## Slurm resources

- Production site settings: partition `Cnode_all`, account `wenswjy`, QoS `normal`, excluded nodes `cnode1057,cnode1015`
- 1 node, 1 task, 16 CPUs, 32G memory, 6-hour wall time
- Array: `1-60%9`

## Execution

```bash
/usr/bin/time -v -o "$TIMELOG" \
    megahit \
        -1 "$R1" -2 "$R2" \
        --kmin-1pass \
        --k-list 27,37,47,57,67,77,87 \
        --min-count 2 \
        --min-contig-len 500 \
        -t "$SLURM_CPUS_PER_TASK" \
        -m 24000000000 \
        -o "$MEGAHIT_DIR" \
        > "$RUNLOG" 2>&1

ln -sfn \
    "megahit/final.contigs.fa" \
    "$SAMPLE_DIR/${SAMPLE}.final.contigs.fa"
```

## Output

- `megahit/final.contigs.fa`
- Standardized `<sample>.final.contigs.fa` symlink
- MEGAHIT run and GNU time logs
- `<sample>.contig_stats.txt`
- `<sample>.contig_length_summary.tsv`
- `<sample>.N50_N90.tsv`
- `.assembly.done`

MEGAHIT intermediate contigs are removed only after successful assembly and QC.

## Quality control

`seqkit stats -a` generates general statistics. Sequence lengths are calculated directly from FASTA content; outputs include counts at 500, 1,000, 1,500, 2,000, 5,000, and 10,000 bp plus N50/N90. The marker is written only after final contigs and all QC products exist.

The archived QC table contains 60 samples:

| Metric | Mean | Range |
| --- | ---: | ---: |
| Assembly size | 335.890 Mb | 202.063–420.898 Mb |
| N50 | 2,061 bp | 1,522–2,989 bp |
| Runtime | 107.69 min | 46.555–183.600 min |
| Maximum resident memory | 7.29 GiB | 6.230–10.271 GiB |

## Verified results

All 60 assemblies have QC records. Mean contig count was 223,521.93 (115,370–284,200). Minimum contig length was 500 bp for every sample.

## Frozen methodological decisions

Individual assembly, k-mer settings, minimum count and contig length, memory parameter, threads, symlink, direct FASTA length calculation, and post-QC intermediate cleanup are frozen.
