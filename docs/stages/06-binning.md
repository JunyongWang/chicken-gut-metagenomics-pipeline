# Stage 06 — multi-binner MAG reconstruction

## Purpose

Recover candidate metagenome-assembled genomes independently with MetaBAT2, MaxBin2, and CONCOCT, then refine the three bin sets with MetaWRAP.

## Input

- Stage 04 per-sample final contigs
- Stage 05 per-sample JGI contig-depth table, coordinate-sorted BAM, and BAI
- Ordered 60-sample list

For each sample, the worker retains assembly contigs at least 2,000 bp long. It subsets the Stage 05 mother depth table to exactly those contigs and derives MaxBin2 abundance from the same table. Both derived tables must contain one row per retained FASTA record.

## Software and version

- MetaBAT2 2.12.1
- MetaWRAP 1.3.2
- MaxBin2: Not captured in the archived production record.
- CONCOCT: Not captured in the archived production record.

## Parameters

| Component | Frozen production settings |
| --- | --- |
| Input preparation | Retain contigs `>= 2000` bp; require depth and abundance rows to equal retained FASTA records |
| MetaBAT2 | `-m 2000 -s 200000 -t 4 --seed 42` |
| MaxBin2 | `-thread 4 -min_contig_length 2000 -markerset 107` |
| CONCOCT split | `cut_up_fasta.py -c 10000 -o 0 -m` |
| CONCOCT | `-c 400 -k 4 -t 4 -l 1000 -s 42` |
| MetaWRAP refinement | `bin_refinement -t 4 -m 48 -c 50 -x 10`, MetaBAT2/MaxBin2/CONCOCT as A/B/C, `--quick` |

## Slurm resources

- Production site settings: partition `Cnode_all`, account `wenswjy`, QoS `normal`, with the node exclusions recorded in the archived array script
- 1 node, 1 task, 4 CPUs, 48G memory, 24-hour wall time
- Array: `1-60`

## Execution

Submit `scripts/06_binning/binning_array.sh`, which resolves one sample and calls `scripts/06_binning/binning_worker.sh`. The portable scripts expose `STAGE_DIR`, `WORK_ROOT`, `SAMPLES_FILE`, and `CONDA_SH`; they retain the production analytical settings and validations.

The checkpoint-aware worker prepares inputs, runs the three binners, refines their outputs, and copies the final bins under sample-prefixed names matching `M*.refined.bin.*`.

## Output

- Contigs at least 2,000 bp long
- Matching MetaBAT2 depth and MaxBin2 abundance subsets
- MetaBAT2, MaxBin2, and CONCOCT bin sets
- MetaWRAP 50/10 refined candidate bins
- Sample-prefixed final refined bins and per-sample summary
- `.metabat2.done`, `.maxbin2.done`, `.concoct.done`, `.refinement.done`, and `.binning.done`

## Quality control

The worker rejects missing inputs, BAMs that fail `samtools quickcheck`, unexpectedly small retained-contig sets, mismatched FASTA/table row counts, empty binner outputs, missing refinement outputs, and final copy-count mismatches. Existing checkpoints are accepted only when their expected output files remain present.

## Verified results

The archived per-sample QC table contains 60 samples.

| Metric | Verified total |
| --- | ---: |
| Input contigs at least 2,000 bp | 1,759,937 |
| MetaBAT2 bins | 5,005 |
| MaxBin2 bins | 4,424 |
| CONCOCT bins | 6,085 |
| Refined candidates | 2,782 |

## Frozen methodological decisions

The 2,000-bp input filter; shared mother depth source; row-count equality checks; binner parameters, threads, and seeds; MetaWRAP 50/10 quick refinement with A/B/C inputs; checkpoint semantics; and sample-prefixed final naming are frozen.
