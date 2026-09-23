#!/usr/bin/env python3

import csv
import os
import re
from collections import Counter, defaultdict


ANN = os.environ.get("MAG_EGGNOG_ANNOTATIONS", "eggnog/11B/final/MAG_eggnog_annotations.tsv")
G2M = os.environ.get("GENE_TO_MAG", "../11B_mag_genes/catalog/MAG_gene_to_MAG.tsv")
OUT = os.environ.get("MAG_KO_OUT", "eggnog/11B/ko_matrix")

EXPECTED_MAG_GENES = 688771
EXPECTED_ANNOTATED = 622522
EXPECTED_MAGS = 374
EXPECTED_KO_GENES = 369671
EXPECTED_MULTI_KO = 30225
EXPECTED_KOS = 5646
EXPECTED_LINKS = 404993

KO_RE = re.compile(r"^ko:(K[0-9]{5})$")


def is_missing(x):
    x = x.strip()
    return x == "" or set(x) == {"-"}


def read_gene_to_mag():
    gene_to_mag = {}
    mag_order = []

    with open(G2M) as f:
        reader = csv.reader(f, delimiter="\t")
        header = next(reader)

        norm = [x.strip().lower() for x in header]

        gene_col = None
        mag_col = None

        for i, x in enumerate(norm):
            if x in (
                "gene",
                "gene_id",
                "geneid",
            ):
                gene_col = i

            if x in (
                "mag",
                "mag_id",
                "genome",
                "genome_id",
            ):
                mag_col = i

        if gene_col is None or mag_col is None:
            raise RuntimeError(
                f"Cannot identify Gene/MAG columns: {header}"
            )

        seen_mags = set()

        for row in reader:
            if not row:
                continue

            gene = row[gene_col]
            mag = row[mag_col]

            if gene in gene_to_mag:
                raise RuntimeError(
                    f"duplicate gene in gene-to-MAG: {gene}"
                )

            gene_to_mag[gene] = mag

            if mag not in seen_mags:
                seen_mags.add(mag)
                mag_order.append(mag)

    if len(gene_to_mag) != EXPECTED_MAG_GENES:
        raise RuntimeError(
            f"MAG gene count {len(gene_to_mag)} "
            f"!= {EXPECTED_MAG_GENES}"
        )

    if len(seen_mags) != EXPECTED_MAGS:
        raise RuntimeError(
            f"MAG count {len(seen_mags)} "
            f"!= {EXPECTED_MAGS}"
        )

    return gene_to_mag, mag_order


def parse_annotations(gene_to_mag):
    gene_kos = {}
    ko_counts = Counter()
    mag_ko_counts = defaultdict(Counter)

    mag_genes_with_ko = Counter()
    mag_links = Counter()

    annotated = 0
    genes_with_ko = 0
    multi_ko = 0
    links = 0
    duplicate_within_gene = 0

    seen_annotation = set()
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

                kcol = header.index("KEGG_ko")
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

            fields = (
                line.rstrip("\n")
                .split("\t")
            )

            if len(fields) <= kcol:
                raise RuntimeError(
                    "malformed eggNOG row"
                )

            gene = fields[0]

            if gene in seen_annotation:
                raise RuntimeError(
                    f"duplicate annotation gene: {gene}"
                )

            seen_annotation.add(gene)
            annotated += 1

            if gene not in gene_to_mag:
                raise RuntimeError(
                    f"annotation gene absent from "
                    f"gene-to-MAG: {gene}"
                )

            value = fields[kcol]

            if is_missing(value):
                continue

            kos = []

            for token in value.split(","):
                token = token.strip()

                m = KO_RE.fullmatch(token)

                if m is None:
                    raise RuntimeError(
                        f"bad KO token: "
                        f"{gene}\t{token}"
                    )

                ko = m.group(1)

                if ko in kos:
                    duplicate_within_gene += 1
                else:
                    kos.append(ko)

            if not kos:
                continue

            genes_with_ko += 1

            if len(kos) > 1:
                multi_ko += 1

            gene_kos[gene] = tuple(kos)

            mag = gene_to_mag[gene]

            mag_genes_with_ko[mag] += 1

            for ko in kos:
                links += 1
                ko_counts[ko] += 1
                mag_ko_counts[mag][ko] += 1
                mag_links[mag] += 1

    if annotated != EXPECTED_ANNOTATED:
        raise RuntimeError(
            f"annotated genes {annotated} "
            f"!= {EXPECTED_ANNOTATED}"
        )

    if genes_with_ko != EXPECTED_KO_GENES:
        raise RuntimeError(
            f"genes with KO {genes_with_ko} "
            f"!= {EXPECTED_KO_GENES}"
        )

    if multi_ko != EXPECTED_MULTI_KO:
        raise RuntimeError(
            f"multi-KO genes {multi_ko} "
            f"!= {EXPECTED_MULTI_KO}"
        )

    if len(ko_counts) != EXPECTED_KOS:
        raise RuntimeError(
            f"unique KOs {len(ko_counts)} "
            f"!= {EXPECTED_KOS}"
        )

    if links != EXPECTED_LINKS:
        raise RuntimeError(
            f"gene-KO links {links} "
            f"!= {EXPECTED_LINKS}"
        )

    if duplicate_within_gene != 0:
        raise RuntimeError(
            "duplicate KO within gene found: "
            f"{duplicate_within_gene}"
        )

    return {
        "gene_kos": gene_kos,
        "ko_counts": ko_counts,
        "mag_ko_counts": mag_ko_counts,
        "mag_genes_with_ko": mag_genes_with_ko,
        "mag_links": mag_links,
        "annotated": annotated,
        "genes_with_ko": genes_with_ko,
        "multi_ko": multi_ko,
        "links": links,
        "duplicate_within_gene": duplicate_within_gene,
    }


os.makedirs(OUT, exist_ok=True)

gene_to_mag, mag_order = read_gene_to_mag()
info = parse_annotations(gene_to_mag)

kos = sorted(info["ko_counts"])


# 1. Gene -> MAG -> KO map
with open(
    os.path.join(
        OUT,
        "MAG_KO_gene_map.tsv"
    ),
    "w",
    newline="",
) as f:

    writer = csv.writer(
        f,
        delimiter="\t",
        lineterminator="\n",
    )

    writer.writerow(
        ["Gene", "MAG", "KO"]
    )

    for gene, gene_kos in (
        info["gene_kos"].items()
    ):
        mag = gene_to_mag[gene]

        for ko in gene_kos:
            writer.writerow(
                [gene, mag, ko]
            )


# 2. MAG x KO matrix
matrix_total = 0

with open(
    os.path.join(
        OUT,
        "MAG_KO_gene_count_matrix.tsv"
    ),
    "w",
    newline="",
) as f:

    writer = csv.writer(
        f,
        delimiter="\t",
        lineterminator="\n",
    )

    writer.writerow(
        ["MAG", *kos]
    )

    for mag in mag_order:
        counts = info[
            "mag_ko_counts"
        ][mag]

        row = [
            counts.get(ko, 0)
            for ko in kos
        ]

        matrix_total += sum(row)

        writer.writerow(
            [mag, *row]
        )


if matrix_total != EXPECTED_LINKS:
    raise RuntimeError(
        f"matrix total {matrix_total} "
        f"!= {EXPECTED_LINKS}"
    )


# 3. KO totals across all MAGs
with open(
    os.path.join(
        OUT,
        "MAG_KO_gene_counts.tsv"
    ),
    "w",
    newline="",
) as f:

    writer = csv.writer(
        f,
        delimiter="\t",
        lineterminator="\n",
    )

    writer.writerow(
        ["KO", "Gene_Count"]
    )

    for ko in kos:
        writer.writerow([
            ko,
            info["ko_counts"][ko],
        ])


# 4. Per-MAG summary
with open(
    os.path.join(
        OUT,
        "MAG_KO_MAG_summary.tsv"
    ),
    "w",
    newline="",
) as f:

    writer = csv.writer(
        f,
        delimiter="\t",
        lineterminator="\n",
    )

    writer.writerow([
        "MAG",
        "Genes_with_KO",
        "Gene_KO_Links",
        "Unique_KOs",
    ])

    for mag in mag_order:
        counts = info[
            "mag_ko_counts"
        ][mag]

        writer.writerow([
            mag,
            info[
                "mag_genes_with_ko"
            ][mag],
            info["mag_links"][mag],
            len(counts),
        ])


# 5. Global summary
with open(
    os.path.join(
        OUT,
        "MAG_KO_matrix_summary.tsv"
    ),
    "w",
) as f:

    f.write("metric\tvalue\n")
    f.write(
        f"input_MAG_genes\t"
        f"{len(gene_to_mag)}\n"
    )
    f.write(
        f"annotated_genes\t"
        f"{info['annotated']}\n"
    )
    f.write(
        f"MAGs\t"
        f"{len(mag_order)}\n"
    )
    f.write(
        f"genes_with_KO\t"
        f"{info['genes_with_ko']}\n"
    )

    f.write(
        f"unique_KOs\t"
        f"{len(kos)}\n"
    )
    f.write(
        f"gene_KO_links\t"
        f"{info['links']}\n"
    )
    f.write(
        f"matrix_total_counts\t"
        f"{matrix_total}\n"
    )
    f.write(
        "duplicate_KO_within_gene\t"
        f"{info['duplicate_within_gene']}\n"
    )
    f.write(
        "multi_KO_rule\t"
        "count_once_in_each_distinct_KO\n"
    )


print("13B complete")
print("MAGs", len(mag_order))
print(
    "genes_with_KO",
    info["genes_with_ko"]
)
print(
    "multi_KO_genes",
    info["multi_ko"]
)
print("unique_KOs", len(kos))
print(
    "gene_KO_links",
    info["links"]
)
print(
    "matrix_total_counts",
    matrix_total
)

