#!/usr/bin/env python3

import csv
import os
import statistics
from pathlib import Path

BASE = Path(os.environ.get("STAGE_DIR", "."))

CHECKM = Path(os.environ.get(
    "CHECKM2_REPORT",
    BASE / "../07_checkm2/checkm2_all/quality_report.tsv",
))
GTDB = Path(os.environ.get(
    "GTDB_SUMMARY",
    BASE / "../09_gtdbtk/gtdbtk_r226/gtdbtk.bac120.summary.tsv",
))

MATRIX_FILES = {
    "relative_abundance": BASE / "matrices/MAG_relative_abundance.tsv",
    "tpm": BASE / "matrices/MAG_tpm.tsv",
    "mean_coverage": BASE / "matrices/MAG_mean_coverage.tsv",
    "covered_fraction": BASE / "matrices/MAG_covered_fraction.tsv",
}

OUT = Path(os.environ.get(
    "MAG_CATALOG_OUT",
    BASE / "catalog/MAG_catalog_metadata.tsv",
))
OUT.parent.mkdir(parents=True, exist_ok=True)


# ============================================================
# CheckM2
# ============================================================

checkm = {}

with CHECKM.open() as f:
    reader = csv.DictReader(f, delimiter="\t")

    for r in reader:
        name = r["Name"]

        checkm[name] = {
            "Completeness": float(r["Completeness"]),
            "Contamination": float(r["Contamination"]),
            "Genome_Size": r.get("Genome_Size", ""),
            "GC_Content": r.get("GC_Content", ""),
            "Contig_N50": r.get("Contig_N50", ""),
            "Total_Contigs": r.get("Total_Contigs", ""),
        }


# ============================================================
# GTDB-Tk
# ============================================================

gtdb = {}

with GTDB.open() as f:
    reader = csv.DictReader(f, delimiter="\t")

    for r in reader:

        name = r["user_genome"]
        classification = r["classification"]

        ranks = classification.split(";")

        while len(ranks) < 7:
            ranks.append("")

        def clean_rank(x):
            if "__" in x:
                return x.split("__", 1)[1]
            return x

        gtdb[name] = {
            "GTDB_classification": classification,
            "Domain": clean_rank(ranks[0]),
            "Phylum": clean_rank(ranks[1]),
            "Class": clean_rank(ranks[2]),
            "Order": clean_rank(ranks[3]),
            "Family": clean_rank(ranks[4]),
            "Genus": clean_rank(ranks[5]),
            "Species": clean_rank(ranks[6]),
            "GTDB_warning": r.get("warnings", ""),
        }


# ============================================================
# CoverM matrices
# ============================================================

coverm = {}

for metric, path in MATRIX_FILES.items():

    with path.open() as f:
        reader = csv.reader(f, delimiter="\t")

        header = next(reader)
        samples = header[1:]

        if len(samples) != 60:
            raise SystemExit(
                f"ERROR: {path} expected 60 samples, got {len(samples)}"
            )

        for row in reader:

            genome = row[0]
            values = [float(x) for x in row[1:]]

            if genome not in coverm:
                coverm[genome] = {}

            coverm[genome][f"Mean_{metric}"] = statistics.mean(values)
            coverm[genome][f"Median_{metric}"] = statistics.median(values)
            coverm[genome][f"Max_{metric}"] = max(values)

            if metric == "relative_abundance":
                coverm[genome]["Samples_RA_gt0"] = sum(
                    x > 0 for x in values
                )


# ============================================================
# Use GTDB representatives as final 374-MAG catalog
# ============================================================

genomes = sorted(gtdb.keys())

if len(genomes) != 374:
    raise SystemExit(
        f"ERROR: expected 374 GTDB genomes, got {len(genomes)}"
    )


# ============================================================
# Write final catalog
# ============================================================

columns = [
    "Genome",
    "Source_sample",

    "Completeness",
    "Contamination",
    "CheckM2_tier",

    "Genome_Size",
    "GC_Content",
    "Contig_N50",
    "Total_Contigs",

    "Domain",
    "Phylum",
    "Class",
    "Order",
    "Family",
    "Genus",
    "Species",
    "GTDB_classification",
    "GTDB_warning",

    "Mean_relative_abundance",
    "Median_relative_abundance",
    "Max_relative_abundance",
    "Samples_RA_gt0",

    "Mean_tpm",
    "Median_tpm",
    "Max_tpm",

    "Mean_mean_coverage",
    "Median_mean_coverage",
    "Max_mean_coverage",

    "Mean_covered_fraction",
    "Median_covered_fraction",
    "Max_covered_fraction",
]


with OUT.open("w", newline="") as f:

    writer = csv.DictWriter(
        f,
        fieldnames=columns,
        delimiter="\t",
        extrasaction="ignore",
    )

    writer.writeheader()

    for genome in genomes:

        if genome not in checkm:
            raise SystemExit(
                f"ERROR: {genome} missing from CheckM2"
            )

        if genome not in coverm:
            raise SystemExit(
                f"ERROR: {genome} missing from CoverM"
            )

        comp = checkm[genome]["Completeness"]
        cont = checkm[genome]["Contamination"]

        if comp >= 90 and cont <= 5:
            tier = "90/5_candidate"
        elif comp >= 80 and cont <= 10:
            tier = "80/10"
        else:
            tier = "50/10"

        row = {
            "Genome": genome,
            "Source_sample": genome.split(".")[0],

            **checkm[genome],
            **gtdb[genome],
            **coverm[genome],

            "CheckM2_tier": tier,
        }

        writer.writerow(row)


print("MAGs:", len(genomes))
print("Output:", OUT)
print("Done.")
