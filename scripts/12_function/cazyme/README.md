# CAZyme downstream reference scripts

`aggregate_dbcan_NR_family.py` aggregates Stage 11A gene TPM and NumReads into numbered CAZy parent families. Within a gene, repeated instances of the same parent family count once; distinct families each receive the full gene abundance. `SLH` is excluded from numbered-family matrices.

`build_MAG_cazyme_matrix.py` creates the 374-MAG × 266-family gene-count matrix and preserves the observed `CBM35inCE17 -> CBM35` normalization.

`build_MAG_weighted_cazyme.py` computes `sum_MAG(family_gene_count * MAG_TPM)` for each family and sample. This MAG-weighted functional potential is distinct from Salmon gene-level CAZyme abundance.

No formal Slurm wrappers were retained for the two MAG Python scripts, so resources are intentionally not invented.
