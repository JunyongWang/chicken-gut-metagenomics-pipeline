# Stage 02 — Bowtie2 host removal

## Purpose

Remove chicken host reads by mapping cleaned pairs to the chicken GRCg7b Bowtie2 index and retaining only pairs for which both mates are unmapped.

## Input

- Stage 01 cleaned paired reads
- Chicken GRCg7b Bowtie2 index
- Ordered `config/samples.txt`

Production used `$HOME/projects/refs/metagenome/host/chicken/GRCg7b/bowtie2_index/GRCg7b`. This is a site-specific provenance path; the portable script requires `HOST_INDEX`.

## Software and version

- Bowtie2 2.5.5
- samtools: Not captured in the archived production script.

## Parameters

| Step | Production setting |
| --- | --- |
| Bowtie2 preset and threads | `--very-sensitive -p 12` |
| Alignment filter | `samtools view -u -f 12 -F 256 -@ 2` |
| Collation | `samtools collate -u -O -@ 2` |
| FASTQ conversion | `samtools fastq -@ 2 ... -n` |

`-f 12` requires both read-unmapped and mate-unmapped bits; `-F 256` excludes secondary alignments. Only pairs with **both mates unmapped** are retained. If either mate maps to chicken, the entire pair is discarded.

## Slurm resources

- Production site settings: partition `Cnode_all`, account `wenswjy`, QoS `normal`, excluded node `cnode1057`
- 1 node, 1 task, 16 CPUs, 32G memory, 6-hour wall time

The script uses `SLURM_ARRAY_TASK_ID`, but the original array range and concurrency are **not captured in the archived production script**. Site settings are documented rather than embedded in the portable script.

## Execution

```bash
bowtie2 \
    --very-sensitive \
    -x "$HOST_INDEX" -1 "$R1" -2 "$R2" -p 12 \
    2> "$MAPLOG" \
| samtools view -u -f 12 -F 256 -@ 2 - \
| samtools collate -u -O -@ 2 - \
| samtools fastq \
    -@ 2 -1 "$OUT_R1" -2 "$OUT_R2" \
    -0 /dev/null -s /dev/null -n - \
    2> "$FASTQLOG"
```

The portable script requires `PROJECT_ROOT`, `HOST_INDEX`, and `CONDA_SH`, with configurable work and stage roots.

## Output

- `<sample>_R1.dehost.fq.gz`
- `<sample>_R2.dehost.fq.gz`
- `<sample>.bowtie2.log`
- `<sample>.samtools_fastq.log`
- `.dehost.done`

## Quality control

Both output FASTQ files must pass `gzip -t` and be non-empty. The marker is created only afterward.

The archived QC table contains 60 samples:

| Metric | Mean | Range |
| --- | ---: | ---: |
| Host pairs removed | 0.2771% | 0.013–2.521% |
| Dehost pair retention | 99.7229% | 97.479–99.987% |

## Verified results

All 60 samples are present. Mean clean input and retained dehost pair counts were 20,829,319.02 and 20,770,272.33.

## Frozen methodological decisions

The GRCg7b reference, Bowtie2 preset, pipeline thread allocation, and strict both-mates-unmapped filter are frozen. The original array range and concurrency remain intentionally undocumented because they were not captured.
