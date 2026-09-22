#!/usr/bin/env python3

import csv
import os


SAMPLE_FILE = os.environ.get("SAMPLES_FILE", "samples.txt")


def read_samples():

    samples = []

    with open(SAMPLE_FILE) as f:
        for line in f:
            sample = line.strip()

            if sample:
                samples.append(sample)

    return samples


def build_matrix(samples, level, prefix):

    # taxid -> taxonomy name
    taxon_names = {}

    # sample -> {taxid: new_est_reads}
    sample_counts = {}

    # taxid -> total abundance across all samples
    total_counts = {}

    # ========================================================
    # Read Bracken files
    # ========================================================

    for sample in samples:

        filename = f"{sample}/{sample}.{level}.bracken"

        if not os.path.isfile(filename):
            raise RuntimeError(
                f"Missing file: {filename}"
            )

        counts = {}

        with open(filename, newline="") as f:

            reader = csv.DictReader(
                f,
                delimiter="\t"
            )

            required = {
                "name",
                "taxonomy_id",
                "taxonomy_lvl",
                "new_est_reads"
            }

            if not required.issubset(reader.fieldnames):
                raise RuntimeError(
                    f"Unexpected Bracken columns in {filename}"
                )

            for row in reader:

                taxid = row["taxonomy_id"]
                name = row["name"]
                taxlvl = row["taxonomy_lvl"]
                count = int(row["new_est_reads"])

                if taxlvl != level:
                    raise RuntimeError(
                        f"Unexpected taxonomy level "
                        f"in {filename}: {taxlvl}"
                    )

                # Check taxid/name consistency
                if taxid in taxon_names:

                    if taxon_names[taxid] != name:
                        raise RuntimeError(
                            f"Taxonomy ID {taxid} "
                            f"has inconsistent names: "
                            f"{taxon_names[taxid]} vs {name}"
                        )

                else:
                    taxon_names[taxid] = name

                counts[taxid] = count

                total_counts[taxid] = (
                    total_counts.get(taxid, 0)
                    + count
                )

        sample_counts[sample] = counts

    # ========================================================
    # Sort taxa by total abundance
    # ========================================================

    taxids = sorted(
        taxon_names.keys(),
        key=lambda x: total_counts.get(x, 0),
        reverse=True
    )

    # ========================================================
    # Count matrix
    # ========================================================

    count_file = f"{prefix}_counts.tsv"

    with open(count_file, "w", newline="") as out:

        writer = csv.writer(
            out,
            delimiter="\t"
        )

        writer.writerow(
            ["taxonomy_id", "name"] + samples
        )

        for taxid in taxids:

            row = [
                taxid,
                taxon_names[taxid]
            ]

            for sample in samples:

                row.append(
                    sample_counts[sample].get(
                        taxid,
                        0
                    )
                )

            writer.writerow(row)

    # ========================================================
    # Relative abundance matrix
    #
    # Value range:
    # 0-1
    #
    # Example:
    # 0.10 = 10%
    # ========================================================

    sample_totals = {}

    for sample in samples:

        sample_totals[sample] = sum(
            sample_counts[sample].values()
        )

        if sample_totals[sample] == 0:

            raise RuntimeError(
                f"No Bracken reads found "
                f"for {sample}, level {level}"
            )

    relative_file = (
        f"{prefix}_relative_abundance.tsv"
    )

    with open(relative_file, "w", newline="") as out:

        writer = csv.writer(
            out,
            delimiter="\t"
        )

        writer.writerow(
            ["taxonomy_id", "name"] + samples
        )

        for taxid in taxids:

            row = [
                taxid,
                taxon_names[taxid]
            ]

            for sample in samples:

                count = (
                    sample_counts[sample]
                    .get(taxid, 0)
                )

                rel = (
                    count
                    / sample_totals[sample]
                )

                row.append(
                    f"{rel:.8f}"
                )

            writer.writerow(row)

    print(
        f"{prefix:<8} "
        f"{len(taxids):>6} taxa, "
        f"{len(samples)} samples"
    )


# ============================================================
# Main
# ============================================================

samples = read_samples()

if len(samples) != 60:

    raise RuntimeError(
        f"Expected 60 samples, "
        f"found {len(samples)}"
    )


LEVELS = [
    ("P", "phylum"),
    ("C", "class"),
    ("O", "order"),
    ("F", "family"),
    ("G", "genus"),
    ("S", "species"),
]


for level, prefix in LEVELS:

    build_matrix(
        samples=samples,
        level=level,
        prefix=prefix
    )


print("ALL MATRICES DONE")
