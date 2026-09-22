# Stage 01 — fastp read QC

## Purpose

Apply paired-end read quality control before host removal. Production automatically detected paired-end adapters, trimmed low-quality sequence from the front and right ends, removed short reads, and filtered low-complexity reads.

## Input

- Raw paired-end files: `<sample>_R1.fq.gz` and `<sample>_R2.fq.gz`
- Ordered `config/samples.txt` containing 60 samples (M1–M61 excluding M23)

The archived input directory was site- and project-specific. The portable script uses the required `RAW_DIR` variable.

## Software and version

- fastp 1.3.6

## Parameters

| Setting | Production value |
| --- | --- |
| Paired-end adapters | `--detect_adapter_for_pe` |
| Front/right cutting | `--cut_front --cut_right` |
| Window and mean quality | `--cut_window_size 4 --cut_mean_quality 20` |
| Minimum length | `--length_required 50` |
| Low complexity | `--low_complexity_filter --complexity_threshold 30` |
| Threads | `SLURM_CPUS_PER_TASK` |

## Slurm resources

- Production site settings: partition `Cnode_all`, account `wenswjy`, QoS `normal`, excluded node `cnode1057`
- 1 node, 1 task, 8 CPUs, 16G memory, 4-hour wall time

The script selects samples through `SLURM_ARRAY_TASK_ID`, but the original array range and concurrency are **not captured in the archived production script**. The portable script therefore does not invent an `#SBATCH --array` directive. Site settings are documented rather than embedded in the portable script.

## Execution

```bash
fastp \
    --in1 "$R1" --in2 "$R2" \
    --out1 "$OUT_R1" --out2 "$OUT_R2" \
    --detect_adapter_for_pe \
    --cut_front --cut_right \
    --cut_window_size 4 \
    --cut_mean_quality 20 \
    --length_required 50 \
    --low_complexity_filter \
    --complexity_threshold 30 \
    --thread "$SLURM_CPUS_PER_TASK" \
    --html "$HTML" --json "$JSON"
```

The portable script requires `PROJECT_ROOT`, `RAW_DIR`, and `CONDA_SH`; `STAGE_DIR`, `SAMPLE_LIST`, and `CONDA_ENV` are configurable.

## Output

- `<sample>_R1.clean.fq.gz`
- `<sample>_R2.clean.fq.gz`
- `<sample>.fastp.html`
- `<sample>.fastp.json`
- `.fastp.done`

## Quality control

Both cleaned FASTQ files must pass `gzip -t`; HTML and JSON reports must be non-empty. The marker is created only after these checks.

The archived QC table contains 60 samples:

| Metric | Mean | Range |
| --- | ---: | ---: |
| Read retention | 98.1405% | 97.96–98.45% |
| Clean-read Q30 | 98.0472% | 97.63–98.52% |

## Verified results

All 60 expected samples are present. Mean raw and clean read counts were 42,446,731.43 and 41,658,638.03.

## Frozen methodological decisions

Adapter detection, quality cutting, minimum length, complexity filtering, and threads are frozen from production. The original array range and concurrency remain intentionally undocumented because they were not captured.
