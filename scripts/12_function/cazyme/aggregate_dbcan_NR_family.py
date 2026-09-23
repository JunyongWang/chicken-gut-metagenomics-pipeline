#!/usr/bin/env python3

import csv
import math
import os
import re
import sys
from collections import Counter

if len(sys.argv) != 5:
    sys.exit(
        "Usage: aggregate_dbcan_NR_family.py "
        "<recommended.tsv> <Gene_TPM.tsv> <Gene_NumReads.tsv> <outdir>"
    )

REC, TPM, NUMREADS, OUTDIR = sys.argv[1:5]

os.makedirs(OUTDIR, exist_ok=True)

EXPECTED_RECOMMENDED = 267092
EXPECTED_NUMBERED_GENES = 267091
EXPECTED_FAMILIES = 291
EXPECTED_LINKS = 275206
EXPECTED_MULTI_FAMILY = 7885
EXPECTED_SLH_GENES = 31
EXPECTED_SLH_TOKENS = 37
EXPECTED_SLH_ONLY = 1
EXPECTED_MATRIX_ROWS = 13151701

EXPECTED_SAMPLES = [
    f"M{i}" for i in range(1, 62)
    if i != 23
]

FAMILY_RE = re.compile(r"^(AA|CBM|CE|GH|GT|PL)([0-9]+)")

CLASS_ORDER = {
    "GH": 0,
    "GT": 1,
    "PL": 2,
    "CE": 3,
    "AA": 4,
    "CBM": 5,
}


def family_sort_key(fam):
    m = re.fullmatch(r"(AA|CBM|CE|GH|GT|PL)([0-9]+)", fam)
    if not m:
        raise RuntimeError(f"Unexpected normalized family: {fam}")
    return (CLASS_ORDER[m.group(1)], int(m.group(2)))


# ============================================================
# 1. Parse dbCAN recommended annotations
# ============================================================

all_genes = set()
gene_order = []
gene_to_families = {}
gene_meta = {}

family_gene_counts = Counter()

multi_family_genes = 0
gene_family_links = 0

slh_rows = []
slh_gene_count = 0
slh_token_count = 0
slh_only_count = 0

with open(REC, newline="") as fh:
    reader = csv.DictReader(fh, delimiter="\t")

    required = {
        "Gene ID",
        "#ofTools",
        "Recommend Results",
    }

    if reader.fieldnames is None:
        raise RuntimeError("Recommended table has no header")

    missing_cols = required - set(reader.fieldnames)
    if missing_cols:
        raise RuntimeError(
            f"Recommended table missing columns: {sorted(missing_cols)}"
        )

    for row in reader:
        gene = row["Gene ID"].strip()
        tools = int(row["#ofTools"])
        rec = row["Recommend Results"].strip()

        if not gene:
            raise RuntimeError("Empty Gene ID")

        if gene in all_genes:
            raise RuntimeError(f"Duplicate recommended Gene ID: {gene}")

        if tools < 2:
            raise RuntimeError(
                f"Recommended table contains #ofTools<2: {gene}"
            )

        if not rec or rec == "-":
            raise RuntimeError(
                f"Missing Recommend Results for recommended gene: {gene}"
            )

        all_genes.add(gene)
        gene_order.append(gene)

        tokens = [
            x.strip()
            for x in rec.split("|")
            if x.strip()
        ]

        families = []
        slh_copies = 0

        for token in tokens:
            if token == "SLH":
                slh_copies += 1
                continue

            m = FAMILY_RE.match(token)

            if m is None:
                raise RuntimeError(
                    f"Unexpected Recommend Results token: "
                    f"{gene}\t{token}\t{rec}"
                )

            parent = m.group(1) + m.group(2)

            # Collapse repeated domains from the same parent family
            # within one gene.
            if parent not in families:
                families.append(parent)

        if slh_copies:
            slh_gene_count += 1
            slh_token_count += slh_copies

        if not families:
            if rec != "SLH":
                raise RuntimeError(
                    f"Gene has no numbered CAZy family but is not "
                    f"SLH-only: {gene}\t{rec}"
                )
            slh_only_count += 1

        if len(families) > 1:
            multi_family_genes += 1

        gene_to_families[gene] = tuple(families)
        gene_meta[gene] = (tools, rec, slh_copies)

        gene_family_links += len(families)

        for fam in families:
            family_gene_counts[fam] += 1

        if slh_copies:
            slh_rows.append(
                (
                    gene,
                    tools,
                    rec,
                    ",".join(families) if families else "-",
                    slh_copies,
                )
            )


numbered_gene_count = sum(
    1 for g in gene_order
    if gene_to_families[g]
)

families = sorted(
    family_gene_counts,
    key=family_sort_key
)

# Frozen structural QC
assert len(all_genes) == EXPECTED_RECOMMENDED
assert numbered_gene_count == EXPECTED_NUMBERED_GENES
assert len(families) == EXPECTED_FAMILIES
assert gene_family_links == EXPECTED_LINKS
assert multi_family_genes == EXPECTED_MULTI_FAMILY
assert slh_gene_count == EXPECTED_SLH_GENES
assert slh_token_count == EXPECTED_SLH_TOKENS
assert slh_only_count == EXPECTED_SLH_ONLY


# ============================================================
# 2. Write gene → family map
# ============================================================

map_file = os.path.join(
    OUTDIR,
    "NR_cazyme_gene_family_map.tsv"
)

with open(map_file, "w", newline="") as out:
    w = csv.writer(
        out,
        delimiter="\t",
        lineterminator="\n"
    )

    w.writerow([
        "Gene",
        "Family",
        "#ofTools",
        "Recommend_Results",
        "Contains_SLH",
    ])

    for gene in gene_order:
        tools, rec, slh_copies = gene_meta[gene]

        for fam in gene_to_families[gene]:
            w.writerow([
                gene,
                fam,
                tools,
                rec,
                "yes" if slh_copies else "no",
            ])


# ============================================================
# 3. Write family gene counts
# ============================================================

count_file = os.path.join(
    OUTDIR,
    "NR_cazyme_family_gene_counts.tsv"
)

with open(count_file, "w", newline="") as out:
    w = csv.writer(
        out,
        delimiter="\t",
        lineterminator="\n"
    )

    w.writerow([
        "Family",
        "Genes",
    ])

    for fam in families:
        w.writerow([
            fam,
            family_gene_counts[fam],
        ])


# ============================================================
# 4. Preserve SLH-containing annotations separately
# ============================================================

slh_file = os.path.join(
    OUTDIR,
    "NR_dbcan_SLH_features.tsv"
)

with open(slh_file, "w", newline="") as out:
    w = csv.writer(
        out,
        delimiter="\t",
        lineterminator="\n"
    )

    w.writerow([
        "Gene",
        "#ofTools",
        "Recommend_Results",
        "Numbered_CAZy_Families",
        "SLH_Copies",
    ])

    for row in slh_rows:
        w.writerow(row)


# ============================================================
# 5. Stream one Salmon matrix and aggregate to families
# ============================================================

def aggregate_matrix(matrix_path, output_name):

    accum = {
        fam: [0.0] * len(EXPECTED_SAMPLES)
        for fam in families
    }

    # Sum each mapped CAZyme gene exactly once.
    unique_gene_sum = [0.0] * len(EXPECTED_SAMPLES)

    # Sum with multi-family genes repeated once per distinct family.
    expanded_gene_sum = [0.0] * len(EXPECTED_SAMPLES)

    seen_targets = set()
    matrix_rows = 0

    with open(matrix_path) as fh:

        header_line = fh.readline()

        if not header_line:
            raise RuntimeError(
                f"Empty matrix: {matrix_path}"
            )

        header = header_line.rstrip("\r\n").split("\t")

        if header[0] != "Gene":
            raise RuntimeError(
                f"First column is not Gene: {matrix_path}"
            )

        samples = header[1:]

        if samples != EXPECTED_SAMPLES:
            raise RuntimeError(
                f"Unexpected sample order in {matrix_path}\n"
                f"Observed: {samples}\n"
                f"Expected: {EXPECTED_SAMPLES}"
            )

        for line in fh:

            if not line.strip():
                continue

            matrix_rows += 1

            gene, sep, rest = line.partition("\t")

            if not sep:
                raise RuntimeError(
                    f"Malformed matrix line in {matrix_path}: "
                    f"{line[:100]}"
                )

            # Fast path: >97% of genes are not recommended CAZymes.
            if gene not in all_genes:
                continue

            if gene in seen_targets:
                raise RuntimeError(
                    f"Duplicate target gene in matrix: {gene}"
                )

            seen_targets.add(gene)

            fields = rest.rstrip("\r\n").split("\t")

            if len(fields) != len(EXPECTED_SAMPLES):
                raise RuntimeError(
                    f"Wrong number of sample values for {gene}: "
                    f"{len(fields)}"
                )

            values = [float(x) for x in fields]

            fams = gene_to_families[gene]

            # SLH-only gene is intentionally not added
            # to any CAZy family.
            if not fams:
                continue

            nfam = len(fams)

            for j, value in enumerate(values):
                unique_gene_sum[j] += value
                expanded_gene_sum[j] += value * nfam

            for fam in fams:
                arr = accum[fam]

                for j, value in enumerate(values):
                    arr[j] += value

    if matrix_rows != EXPECTED_MATRIX_ROWS:
        raise RuntimeError(
            f"Matrix row count mismatch for {matrix_path}: "
            f"{matrix_rows} != {EXPECTED_MATRIX_ROWS}"
        )

    if seen_targets != all_genes:
        missing = sorted(all_genes - seen_targets)
        raise RuntimeError(
            f"{len(missing)} recommended genes missing from "
            f"{matrix_path}; examples: {missing[:10]}"
        )

    # Independent abundance-conservation check:
    # family matrix sum must equal gene abundance expanded
    # according to number of distinct parent families.
    family_sum = [
        sum(accum[fam][j] for fam in families)
        for j in range(len(EXPECTED_SAMPLES))
    ]

    for sample, observed, expected in zip(
        EXPECTED_SAMPLES,
        family_sum,
        expanded_gene_sum,
    ):
        if not math.isclose(
            observed,
            expected,
            rel_tol=1e-10,
            abs_tol=1e-6,
        ):
            raise RuntimeError(
                f"Family abundance conservation failed: "
                f"{sample}: {observed} != {expected}"
            )

    outfile = os.path.join(
        OUTDIR,
        output_name
    )

    with open(outfile, "w", newline="") as out:
        w = csv.writer(
            out,
            delimiter="\t",
            lineterminator="\n"
        )

        w.writerow([
            "Family",
            *EXPECTED_SAMPLES,
        ])

        for fam in families:
            w.writerow([
                fam,
                *[f"{x:.6f}" for x in accum[fam]],
            ])

    return {
        "matrix_rows": matrix_rows,
        "matched_recommended": len(seen_targets),
        "unique_gene_sum": unique_gene_sum,
        "expanded_gene_sum": expanded_gene_sum,
    }


# ============================================================
# 6. Aggregate TPM and NumReads
# ============================================================

tpm_stats = aggregate_matrix(
    TPM,
    "NR_cazyme_family_TPM.tsv"
)

num_stats = aggregate_matrix(
    NUMREADS,
    "NR_cazyme_family_NumReads.tsv"
)


# ============================================================
# 7. Per-sample QC table
# ============================================================

qc_file = os.path.join(
    OUTDIR,
    "NR_cazyme_abundance_QC.tsv"
)

with open(qc_file, "w", newline="") as out:
    w = csv.writer(
        out,
        delimiter="\t",
        lineterminator="\n"
    )

    w.writerow([
        "Sample",
        "Unique_CAZy_Gene_TPM",
        "Family_Expanded_TPM",
        "TPM_Expansion_Ratio",
        "Unique_CAZy_Gene_NumReads",
        "Family_Expanded_NumReads",
        "NumReads_Expansion_Ratio",
    ])

    for j, sample in enumerate(EXPECTED_SAMPLES):

        ut = tpm_stats["unique_gene_sum"][j]
        et = tpm_stats["expanded_gene_sum"][j]

        un = num_stats["unique_gene_sum"][j]
        en = num_stats["expanded_gene_sum"][j]

        t_ratio = et / ut if ut != 0 else 0.0
        n_ratio = en / un if un != 0 else 0.0

        w.writerow([
            sample,
            f"{ut:.6f}",
            f"{et:.6f}",
            f"{t_ratio:.8f}",
            f"{un:.6f}",
            f"{en:.6f}",
            f"{n_ratio:.8f}",
        ])


# ============================================================
# 8. Final summary
# ============================================================

summary_file = os.path.join(
    OUTDIR,
    "NR_cazyme_family_summary.tsv"
)

with open(summary_file, "w") as out:

    def emit(key, value):
        out.write(f"{key}\t{value}\n")

    emit("metric", "value")
    emit("recommended_genes", len(all_genes))
    emit("genes_with_numbered_cazy_family", numbered_gene_count)
    emit("slh_containing_genes", slh_gene_count)
    emit("slh_tokens", slh_token_count)
    emit("slh_only_genes", slh_only_count)
    emit("multi_parent_family_genes", multi_family_genes)
    emit("unique_parent_families", len(families))
    emit("gene_family_links", gene_family_links)
    emit("samples", len(EXPECTED_SAMPLES))
    emit("tpm_matrix_gene_rows", tpm_stats["matrix_rows"])
    emit(
        "tpm_matched_recommended_genes",
        tpm_stats["matched_recommended"]
    )
    emit("numreads_matrix_gene_rows", num_stats["matrix_rows"])
    emit(
        "numreads_matched_recommended_genes",
        num_stats["matched_recommended"]
    )
    emit(
        "family_rule",
        "parent_CAZy_family"
    )
    emit(
        "within_gene_duplicate_family_rule",
        "count_once"
    )
    emit(
        "multi_family_gene_rule",
        "full_abundance_to_each_distinct_family"
    )
    emit(
        "slh_rule",
        "exclude_SLH_from_family_matrix_keep_numbered_partner_families"
    )

print("Aggregation complete")
print(f"Recommended genes: {len(all_genes)}")
print(f"Numbered-family genes: {numbered_gene_count}")
print(f"Families: {len(families)}")
print(f"Gene-family links: {gene_family_links}")
print(f"SLH genes: {slh_gene_count}")
print(f"SLH-only genes: {slh_only_count}")
