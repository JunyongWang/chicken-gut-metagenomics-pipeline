# Stage 03 — Kraken2 and Bracken taxonomic profiling

## Purpose

Classify host-removed paired reads with Kraken2 and re-estimate abundance with Bracken at phylum, class, order, family, genus, and species levels.

## Input

- Stage 02 dehost paired reads
- Kraken2/Bracken database `standard_20260626`
- Ordered `config/samples.txt`

Production used `$HOME/projects/refs/metagenome/kraken2/standard_20260626`. The portable script requires `KRAKEN_DB`.

## Software and version

- Kraken2 2.17.1
- Bracken 3.0.1

## Parameters

| Component | Production setting |
| --- | --- |
| Kraken2 input | `--paired --gzip-compressed` |
| Threads | 32 |
| Confidence and names | `--confidence 0 --use-names` |
| Bracken read length | `150` |
| Bracken threshold | `10` |
| Bracken levels | `P C O F G S` |
| Per-read compression | `pigz -p 8` |

## Slurm resources

- Production site settings: partition `Cnode_all`, account `wenswjy`, QoS `normal`, excluded nodes `cnode1057,cnode1015`
- 1 node, 1 task, 32 CPUs, 160G memory, 6-hour wall time
- Array: `1-60%6`

The portable script retains CPU, memory, time, and array directives; site-specific settings are documented here.

## Execution

```bash
kraken2 \
    --db "$DB" \
    --paired --gzip-compressed \
    --threads "$SLURM_CPUS_PER_TASK" \
    --confidence 0 --use-names \
    --report "$REPORT" --output "$KOUT" \
    "$R1" "$R2"

for LEVEL in P C O F G S; do
    bracken \
        -d "$DB" -i "$REPORT" \
        -o "$OUTDIR/$SAMPLE.$LEVEL.bracken" \
        -r 150 -l "$LEVEL" -t 10
done
```

## Output

- `<sample>.kraken.report`
- `<sample>.kraken.output.gz`
- `<sample>.kraken.log`
- Six `<sample>.<level>.bracken` outputs and logs
- Bracken-generated Kraken-style reports
- `.kraken_bracken.done`

The archived matrix helper builds count and relative-abundance matrices from Bracken results.

## Quality control

The workflow validates the Kraken2 database files and 150-mer Bracken distribution; requires non-empty Kraken2 report, per-read output, and six Bracken outputs; compresses the per-read output; and runs `gzip -t`. The marker is created only after every check.

The archived QC table contains 60 samples:

| Metric | Mean | Range |
| --- | ---: | ---: |
| Classified pairs | 47.8797% | 40.34–58.25% |
| Bacterial fraction | 47.2848% | 39.27–57.80% |

## Verified results

All 60 samples have QC records. Mean classified and unclassified pair counts were 9,941,972.15 and 10,828,300.18.

## Frozen methodological decisions

Database `standard_20260626`, zero confidence, paired compressed input, taxon names, Bracken read length and threshold, six levels, compression, and completion-marker ordering are frozen.
