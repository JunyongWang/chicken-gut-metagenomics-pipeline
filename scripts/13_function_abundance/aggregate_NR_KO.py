#!/usr/bin/env python3

import csv
import math
import os
import re


ANN = os.environ.get("NR_EGGNOG_ANNOTATIONS", "eggnog/11A/final/NR_eggnog_annotations.tsv")

TPM = os.environ.get(
    "GENE_TPM",
    "../11_gene_catalog/salmon/matrices/Gene_TPM.tsv",
)

NUM = os.environ.get(
    "GENE_NUMREADS",
    "../11_gene_catalog/salmon/matrices/Gene_NumReads.tsv",
)

OUT = os.environ.get("NR_KO_OUT", "eggnog/11A/ko_abundance")

EXPECTED_ANNOTATED = 10813185
EXPECTED_MATRIX_ROWS = 13151701

SAMPLES = [
    f"M{i}"
    for i in range(1, 62)
    if i != 23
]

KO_RE = re.compile(
    r"^ko:(K[0-9]{5})$"
)


def is_missing(value):
    value = value.strip()

    return (
        value == ""
        or set(value) == {"-"}
    )


def parse_annotations():
    gene_kos = {}

    ko_set = set()

    annotated_rows = 0
    genes_with_ko = 0
    multi_ko_genes = 0
    gene_ko_links = 0
    duplicate_ko = 0

    kcol = None

    with open(ANN) as f:
        for line in f:

            if line.startswith("##"):
                continue

            if line.startswith("#query\t"):
                header = (
                    line.rstrip("\n")
                    .split("\t")
                )

                if "KEGG_ko" not in header:
                    raise RuntimeError(
                        "KEGG_ko column missing"
                    )

                kcol = header.index(
                    "KEGG_ko"
                )

                continue

            if (
                line.startswith("#")
                or not line.strip()
            ):
                continue

            if kcol is None:
                raise RuntimeError(
                    "eggNOG header not found"
                )

            annotated_rows += 1

            fields = (
                line.rstrip("\n")
                .split("\t")
            )

            if len(fields) <= kcol:
                raise RuntimeError(
                    "malformed eggNOG row"
                )

            gene = fields[0]
            value = fields[kcol]

            if is_missing(value):
                continue

            kos = []

            for token in value.split(","):
                token = token.strip()

                m = KO_RE.fullmatch(
                    token
                )

                if m is None:
                    raise RuntimeError(
                        "bad KO token: "
                        f"{gene}\t{token}"
                    )

                ko = m.group(1)

                if ko in kos:
                    duplicate_ko += 1
                else:
                    kos.append(ko)

            if not kos:
                continue

            if gene in gene_kos:
                raise RuntimeError(
                    "duplicate KO gene: "
                    f"{gene}"
                )

            genes_with_ko += 1

            if len(kos) > 1:
                multi_ko_genes += 1

            gene_kos[gene] = tuple(kos)

            gene_ko_links += len(kos)

            ko_set.update(kos)

    if (
        annotated_rows
        != EXPECTED_ANNOTATED
    ):
        raise RuntimeError(
            "annotation rows "
            f"{annotated_rows} != "
            f"{EXPECTED_ANNOTATED}"
        )

    if (
        genes_with_ko
        != len(gene_kos)
    ):
        raise RuntimeError(
            "KO gene count mismatch"
        )

    return {
        "gene_kos": gene_kos,
        "kos": sorted(ko_set),
        "annotated_rows": annotated_rows,
        "genes_with_ko": genes_with_ko,
        "multi_ko_genes": multi_ko_genes,
        "gene_ko_links": gene_ko_links,
        "duplicate_ko": duplicate_ko,
    }


def aggregate_matrix(
    path,
    gene_kos,
    kos,
    outfile,
):

    accum = {
        ko: [0.0] * len(SAMPLES)
        for ko in kos
    }

    unique_sum = [
        0.0
        for _ in SAMPLES
    ]

    expanded_sum = [
        0.0
        for _ in SAMPLES
    ]

    matrix_rows = 0
    matched = set()

    with open(path) as f:

        header = (
            f.readline()
            .rstrip("\n")
            .split("\t")
        )

        if header[0] != "Gene":
            raise RuntimeError(
                "bad matrix header: "
                f"{path}"
            )

        if header[1:] != SAMPLES:
            raise RuntimeError(
                "sample order mismatch: "
                f"{path}"
            )

        for line in f:

            if not line.strip():
                continue

            matrix_rows += 1

            gene, sep, rest = (
                line.partition("\t")
            )

            if not sep:
                raise RuntimeError(
                    "malformed matrix row: "
                    f"{gene}"
                )

            if gene not in gene_kos:
                continue

            if gene in matched:
                raise RuntimeError(
                    "duplicate matrix gene: "
                    f"{gene}"
                )

            matched.add(gene)

            values = [
                float(x)
                for x in (
                    rest.rstrip("\n")
                    .split("\t")
                )
            ]

            if (
                len(values)
                != len(SAMPLES)
            ):
                raise RuntimeError(
                    "bad sample count: "
                    f"{gene}"
                )

            kos_for_gene = (
                gene_kos[gene]
            )

            nko = len(kos_for_gene)

            for j, value in enumerate(
                values
            ):
                unique_sum[j] += value
                expanded_sum[j] += (
                    value * nko
                )

            for ko in kos_for_gene:
                target = accum[ko]

                for j, value in enumerate(
                    values
                ):
                    target[j] += value

    if (
        matrix_rows
        != EXPECTED_MATRIX_ROWS
    ):
        raise RuntimeError(
            "matrix rows "
            f"{matrix_rows} != "
            f"{EXPECTED_MATRIX_ROWS}"
        )

    if (
        len(matched)
        != len(gene_kos)
    ):
        raise RuntimeError(
            "KO genes missing from "
            f"{path}: "
            f"{len(gene_kos)-len(matched)}"
        )

    observed = [
        sum(
            accum[ko][j]
            for ko in kos
        )
        for j in range(
            len(SAMPLES)
        )
    ]

    for sample, obs, exp in zip(
        SAMPLES,
        observed,
        expanded_sum,
    ):
        if not math.isclose(
            obs,
            exp,
            rel_tol=1e-10,
            abs_tol=1e-5,
        ):
            raise RuntimeError(
                "conservation failed: "
                f"{sample} "
                f"{obs} != {exp}"
            )

    outpath = os.path.join(
        OUT,
        outfile,
    )

    with open(
        outpath,
        "w",
        newline="",
    ) as f:

        writer = csv.writer(
            f,
            delimiter="\t",
            lineterminator="\n",
        )

        writer.writerow(
            ["KO", *SAMPLES]
        )

        for ko in kos:
            writer.writerow(
                [
                    ko,
                    *[
                        f"{x:.6f}"
                        for x
                        in accum[ko]
                    ],
                ]
            )

    return {
        "matrix_rows": matrix_rows,
        "matched_genes": len(
            matched
        ),
        "unique_sum": unique_sum,
        "expanded_sum": expanded_sum,
    }


os.makedirs(
    OUT,
    exist_ok=True,
)

info = parse_annotations()

gene_kos = info["gene_kos"]
kos = info["kos"]


map_path = os.path.join(
    OUT,
    "NR_KO_gene_map.tsv",
)

with open(
    map_path,
    "w",
    newline="",
) as f:

    writer = csv.writer(
        f,
        delimiter="\t",
        lineterminator="\n",
    )

    writer.writerow(
        ["Gene", "KO"]
    )

    for gene, gene_list in (
        gene_kos.items()
    ):
        for ko in gene_list:
            writer.writerow(
                [gene, ko]
            )


tpm = aggregate_matrix(
    TPM,
    gene_kos,
    kos,
    "NR_KO_TPM.tsv",
)

num = aggregate_matrix(
    NUM,
    gene_kos,
    kos,
    "NR_KO_NumReads.tsv",
)


qc_path = os.path.join(
    OUT,
    "NR_KO_abundance_QC.tsv",
)

with open(
    qc_path,
    "w",
    newline="",
) as f:

    writer = csv.writer(
        f,
        delimiter="\t",
        lineterminator="\n",
    )

    writer.writerow([
        "Sample",
        "Unique_KO_Gene_TPM",
        "KO_Expanded_TPM",
        "TPM_Expansion_Ratio",
        "Unique_KO_Gene_NumReads",
        "KO_Expanded_NumReads",
        "NumReads_Expansion_Ratio",
    ])

    for j, sample in enumerate(
        SAMPLES
    ):
        ut = tpm[
            "unique_sum"
        ][j]

        et = tpm[
            "expanded_sum"
        ][j]

        un = num[
            "unique_sum"
        ][j]

        en = num[
            "expanded_sum"
        ][j]

        writer.writerow([
            sample,
            f"{ut:.6f}",
            f"{et:.6f}",
            f"{et / ut:.8f}"
            if ut else "0",
            f"{un:.6f}",
            f"{en:.6f}",
            f"{en / un:.8f}"
            if un else "0",
        ])


summary_path = os.path.join(
    OUT,
    "NR_KO_summary.tsv",
)

with open(
    summary_path,
    "w",
) as f:

    f.write(
        "metric\tvalue\n"
    )

    f.write(
        "annotated_genes\t"
        f"{info['annotated_rows']}\n"
    )

    f.write(
        "genes_with_KO\t"
        f"{info['genes_with_ko']}\n"
    )

    f.write(
        "multi_KO_genes\t"
        f"{info['multi_ko_genes']}\n"
    )

    f.write(
        "unique_KOs\t"
        f"{len(kos)}\n"
    )

    f.write(
        "gene_KO_links\t"
        f"{info['gene_ko_links']}\n"
    )

    f.write(
        "duplicate_KO_within_gene\t"
        f"{info['duplicate_ko']}\n"
    )

    f.write(
        "tpm_matrix_rows\t"
        f"{tpm['matrix_rows']}\n"
    )

    f.write(
        "tpm_matched_KO_genes\t"
        f"{tpm['matched_genes']}\n"
    )

    f.write(
        "numreads_matrix_rows\t"
        f"{num['matrix_rows']}\n"
    )

    f.write(
        "numreads_matched_KO_genes\t"
        f"{num['matched_genes']}\n"
    )

    f.write(
        "multi_KO_rule\t"
        "full_abundance_to_each_"
        "distinct_KO\n"
    )


print("13A complete")

print(
    "annotated_genes",
    info["annotated_rows"],
)

print(
    "genes_with_KO",
    info["genes_with_ko"],
)

print(
    "multi_KO_genes",
    info["multi_ko_genes"],
)

print(
    "unique_KOs",
    len(kos),
)

print(
    "gene_KO_links",
    info["gene_ko_links"],
)
