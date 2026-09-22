# Stage 08 — species-level dereplication

## Purpose

Dereplicate the CheckM2 50/10 MAG set at 95% secondary ANI and select one representative per secondary cluster.

## Input

- Exactly 2,672 MAGs passing CheckM2 completeness `>= 50%` and contamination `<= 10%`
- `genomeInfo.csv` with 2,672 data rows plus its header

The filtering criterion and final 2,672-MAG input set are verified biological and computational decisions. The exact historical staging command used to create `input_mags` and `genomeInfo.csv` was not captured in the archived production record. This unarchived file-staging mechanism does not alter the verified filter or final input set.

## Software and version

- dRep 3.7.1
- fastANI 1.34
- Mash 2.3

## Parameters

```text
-comp 50 -con 10 -pa 0.90 -sa 0.95 -nc 0.30
-cm larger --S_algorithm fastANI -p 4
```

## Slurm resources

- Production site settings: partition `Cnode_all`, account `wenswjy`, QoS `normal`, with archived node exclusions
- 1 node, 1 task, 4 CPUs, 16G memory, 48-hour wall time

## Execution

Run `scripts/08_drep/drep_all.sh` with `STAGE_DIR` and `CONDA_SH` set. `MAG_DIR`, `GENOME_INFO`, and `DREP_OUT` expose the input, metadata, and output locations without changing the production parameters.

## Output

- dRep work directory `drep_95`
- `dereplicated_genomes` containing representative MAGs
- GNU time log and dRep log
- `.drep95.done`

## Quality control

The portable script accepts regular `.fa` files and symbolic links to `.fa` files and requires exactly 2,672 inputs. It refuses to overwrite an existing dRep output directory and requires the `dereplicated_genomes` directory after completion.

## Verified results

- Input MAGs: 2,672
- Primary clusters: 295
- Dereplicated representative MAGs: 374
- Secondary ANI: 95%

All downstream GTDB-Tk, CoverM, and MAG-specific gene analyses use these 374 representatives.

## Frozen methodological decisions

The CheckM2 50/10 input set, primary ANI 0.90, secondary ANI 0.95, minimum coverage 0.30, `larger` cluster method, fastANI secondary algorithm, four threads, and the resulting 374-representative handoff are frozen.
