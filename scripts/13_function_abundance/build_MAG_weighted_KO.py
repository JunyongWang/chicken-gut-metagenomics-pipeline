#!/usr/bin/env python3

import csv
import math
import os


TPM = os.environ.get("MAG_TPM", "../10_coverm/matrices/MAG_tpm.tsv")

KO_MATRIX = os.environ.get(
    "KO_MATRIX",
    "eggnog/11B/ko_matrix/MAG_KO_gene_count_matrix.tsv",
)

OUT = os.environ.get("MAG_WEIGHTED_KO_OUT", "eggnog/11B/ko_weighted")

EXPECTED_MAGS = 374
EXPECTED_KOS = 5646

SAMPLES = [
    f"M{i}"
    for i in range(1, 62)
    if i != 23
]


def read_tpm():
    data = {}
    mag_order = []

    with open(TPM) as f:
        reader = csv.reader(
            f,
            delimiter="\t",
        )

        header = next(reader)

        if header[0] != "Genome":
            raise RuntimeError(
                "CoverM first column is not Genome"
            )

        if header[1:] != SAMPLES:
            raise RuntimeError(
                "CoverM sample order mismatch"
            )

        for row in reader:
            if not row:
                continue

            mag = row[0]

            if mag in data:
                raise RuntimeError(
                    f"duplicate MAG in TPM: {mag}"
                )

            values = [
                float(x)
                for x in row[1:]
            ]

            if len(values) != len(SAMPLES):
                raise RuntimeError(
                    f"bad TPM sample count: {mag}"
                )

            if any(x < 0 for x in values):
                raise RuntimeError(
                    f"negative TPM: {mag}"
                )

            data[mag] = values
            mag_order.append(mag)

    if len(data) != EXPECTED_MAGS:
        raise RuntimeError(
            f"TPM MAG count {len(data)} "
            f"!= {EXPECTED_MAGS}"
        )

    return data, mag_order


def read_ko_matrix():
    data = {}
    ko_names = None

    with open(KO_MATRIX) as f:
        reader = csv.reader(
            f,
            delimiter="\t",
        )

        header = next(reader)

        if header[0] != "MAG":
            raise RuntimeError(
                "KO matrix first column is not MAG"
            )

        ko_names = header[1:]

        if len(ko_names) != EXPECTED_KOS:
            raise RuntimeError(
                f"KO count {len(ko_names)} "
                f"!= {EXPECTED_KOS}"
            )

        if len(set(ko_names)) != len(ko_names):
            raise RuntimeError(
                "duplicate KO columns"
            )

        for row in reader:
            if not row:
                continue

            mag = row[0]

            if mag in data:
                raise RuntimeError(
                    f"duplicate MAG in KO matrix: {mag}"
                )

            values = [
                int(x)
                for x in row[1:]
            ]

            if len(values) != len(ko_names):
                raise RuntimeError(
                    f"bad KO column count: {mag}"
                )

            if any(x < 0 for x in values):
                raise RuntimeError(
                    f"negative KO count: {mag}"
                )

            data[mag] = values

    if len(data) != EXPECTED_MAGS:
        raise RuntimeError(
            f"KO matrix MAG count {len(data)} "
            f"!= {EXPECTED_MAGS}"
        )

    return ko_names, data


os.makedirs(
    OUT,
    exist_ok=True,
)

tpm, tpm_mag_order = read_tpm()

kos, counts = read_ko_matrix()


if set(tpm) != set(counts):
    only_tpm = sorted(
        set(tpm) - set(counts)
    )

    only_ko = sorted(
        set(counts) - set(tpm)
    )

    raise RuntimeError(
        "MAG set mismatch\n"
        f"TPM only: {only_tpm[:10]}\n"
        f"KO only: {only_ko[:10]}"
    )


weighted = [
    [0.0] * len(SAMPLES)
    for _ in kos
]

expected_total = [
    0.0
    for _ in SAMPLES
]

tpm_sum = [
    0.0
    for _ in SAMPLES
]


for mag in tpm_mag_order:

    mag_tpm = tpm[mag]
    mag_counts = counts[mag]

    links = sum(mag_counts)

    for j, value in enumerate(
        mag_tpm
    ):
        tpm_sum[j] += value

        expected_total[j] += (
            value * links
        )

    for k, count in enumerate(
        mag_counts
    ):
        if count == 0:
            continue

        target = weighted[k]

        for j, value in enumerate(
            mag_tpm
        ):
            target[j] += (
                count * value
            )


observed_total = [
    sum(
        weighted[k][j]
        for k in range(len(kos))
    )
    for j in range(len(SAMPLES))
]


differences = []

for sample, obs, exp in zip(
    SAMPLES,
    observed_total,
    expected_total,
):
    diff = abs(obs - exp)
    differences.append(diff)

    if not math.isclose(
        obs,
        exp,
        rel_tol=1e-12,
        abs_tol=1e-5,
    ):
        raise RuntimeError(
            "conservation failed: "
            f"{sample}: "
            f"{obs} != {exp}"
        )


matrix_path = os.path.join(
    OUT,
    "MAG_weighted_KO_TPM.tsv",
)

with open(
    matrix_path,
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

    for ko, values in zip(
        kos,
        weighted,
    ):
        writer.writerow([
            ko,
            *[
                f"{x:.6f}"
                for x in values
            ],
        ])


qc_path = os.path.join(
    OUT,
    "MAG_weighted_KO_QC.tsv",
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
        "MAG_TPM_Sum",
        "Weighted_Total",
        "Independent_Expected_Total",
        "Absolute_Difference",
    ])

    for j, sample in enumerate(
        SAMPLES
    ):
        writer.writerow([
            sample,
            f"{tpm_sum[j]:.6f}",
            f"{observed_total[j]:.6f}",
            f"{expected_total[j]:.6f}",
            f"{differences[j]:.12f}",
        ])


summary_path = os.path.join(
    OUT,
    "MAG_weighted_KO_summary.tsv",
)

with open(
    summary_path,
    "w",
) as f:

    f.write("metric\tvalue\n")

    f.write(
        f"MAGs\t{len(tpm)}\n"
    )

    f.write(
        f"KOs\t{len(kos)}\n"
    )

    f.write(
        f"samples\t{len(SAMPLES)}\n"
    )

    f.write(
        "weight_metric\t"
        "CoverM_genome_TPM\n"
    )

    f.write(
        "formula\t"
        "sum_MAG("
        "KO_gene_count*MAG_TPM"
        ")\n"
    )

    f.write(
        "min_MAG_TPM_sum\t"
        f"{min(tpm_sum):.6f}\n"
    )

    f.write(
        "max_MAG_TPM_sum\t"
        f"{max(tpm_sum):.6f}\n"
    )

    f.write(
        "max_conservation_error\t"
        f"{max(differences):.12f}\n"
    )


print("13C complete")

print(
    "MAGs",
    len(tpm),
    "KOs",
    len(kos),
    "samples",
    len(SAMPLES),
)

print(
    "MAG TPM sum range",
    f"{min(tpm_sum):.6f}",
    f"{max(tpm_sum):.6f}",
)

print(
    "max conservation error",
    f"{max(differences):.12f}",
)
