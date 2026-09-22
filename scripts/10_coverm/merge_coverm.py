#!/usr/bin/env python3

import csv
import os
from pathlib import Path

BASE = Path(os.environ.get("STAGE_DIR", "."))
RESULTS = BASE / "results"
SAMPLES_FILE = Path(os.environ.get("SAMPLES_FILE", BASE / "samples.txt"))
OUTDIR = BASE / "matrices"

OUTDIR.mkdir(exist_ok=True)

samples = [
    x.strip()
    for x in SAMPLES_FILE.read_text().splitlines()
    if x.strip()
]

if len(samples) != 60:
    raise SystemExit(f"ERROR: expected 60 samples, got {len(samples)}")

metrics = {
    "mean_coverage": 1,
    "covered_fraction": 2,
    "relative_abundance": 3,
    "tpm": 4,
}

data = {m: {} for m in metrics}
reference_genomes = None

mapping_rows = []

for sample in samples:

    infile = RESULTS / sample / f"{sample}.coverm.tsv"

    if not infile.exists():
        raise SystemExit(f"ERROR: missing {infile}")

    rows = []

    with infile.open() as f:
        reader = csv.reader(f, delimiter="\t")
        header = next(reader)

        if len(header) != 5:
            raise SystemExit(
                f"ERROR: unexpected column number in {sample}: {len(header)}"
            )

        for row in reader:
            if len(row) != 5:
                raise SystemExit(
                    f"ERROR: malformed row in {sample}: {row}"
                )
            rows.append(row)

    # 374 MAG + 1 unmapped
    if len(rows) != 375:
        raise SystemExit(
            f"ERROR: {sample} expected 375 data rows, got {len(rows)}"
        )

    unmapped = [r for r in rows if r[0] == "unmapped"]

    if len(unmapped) != 1:
        raise SystemExit(
            f"ERROR: {sample} does not contain exactly one unmapped row"
        )

    unmapped_percent = float(unmapped[0][3])
    mapped_percent = 100.0 - unmapped_percent

    mapping_rows.append([
        sample,
        f"{mapped_percent:.6f}",
        f"{unmapped_percent:.6f}",
    ])

    mag_rows = [r for r in rows if r[0] != "unmapped"]

    if len(mag_rows) != 374:
        raise SystemExit(
            f"ERROR: {sample} expected 374 MAGs, got {len(mag_rows)}"
        )

    current_genomes = [r[0] for r in mag_rows]

    if len(set(current_genomes)) != 374:
        raise SystemExit(
            f"ERROR: duplicated MAG names in {sample}"
        )

    if reference_genomes is None:
        reference_genomes = current_genomes
    elif set(current_genomes) != set(reference_genomes):
        raise SystemExit(
            f"ERROR: MAG set differs in {sample}"
        )

    rowdict = {r[0]: r for r in mag_rows}

    for metric, col in metrics.items():
        for genome in reference_genomes:
            data[metric].setdefault(genome, {})
            data[metric][genome][sample] = rowdict[genome][col]


# Write four matrices
for metric in metrics:

    outfile = OUTDIR / f"MAG_{metric}.tsv"

    with outfile.open("w", newline="") as f:
        writer = csv.writer(f, delimiter="\t")

        writer.writerow(["Genome"] + samples)

        for genome in reference_genomes:
            writer.writerow(
                [genome] +
                [data[metric][genome][s] for s in samples]
            )


# Write mapping summary
with (OUTDIR / "mapping_summary.tsv").open("w", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow([
        "Sample",
        "Mapped_percent",
        "Unmapped_percent"
    ])
    writer.writerows(mapping_rows)


print("Samples:", len(samples))
print("MAGs:", len(reference_genomes))
print("Matrices: 4")
print("Done.")
