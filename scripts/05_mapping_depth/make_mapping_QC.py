#!/usr/bin/env python3

import csv
import os
import re

SAMPLES_FILE = os.environ.get("SAMPLES_FILE", "samples.txt")
ASSEMBLY_DIR = os.environ.get("ASSEMBLY_DIR", "../04_assembly")
OUTFILE = os.environ.get("OUTFILE", "mapping_QC_summary.tsv")


def parse_elapsed(value):
    parts = value.strip().split(":")

    if len(parts) == 3:
        h = int(parts[0])
        m = int(parts[1])
        s = float(parts[2])
        return h * 3600 + m * 60 + s

    elif len(parts) == 2:
        m = int(parts[0])
        s = float(parts[1])
        return m * 60 + s

    return float(parts[0])


with open(SAMPLES_FILE) as f:
    samples = [x.strip() for x in f if x.strip()]


columns = [
    "Sample",
    "Overall_alignment_percent",
    "Properly_paired_percent",
    "Singletons_percent",
    "Mapped_reads",
    "Total_reads",
    "Assembly_contigs",
    "Depth_rows",
    "Depth_complete",
    "BAM_GiB",
    "Runtime_min",
    "Runtime_hour",
    "MaxRSS_GiB",
    "CPU_percent"
]

rows = []


for sample in samples:

    bowtie_log = f"{sample}/{sample}.bowtie2.log"
    flagstat = f"{sample}/{sample}.flagstat.txt"
    depth = f"{sample}/{sample}.contig_depth.tsv"
    bam = f"{sample}/{sample}.contigs.sorted.bam"
    time_log = f"{sample}/{sample}.mapping.time.log"

    contigs = (
        f"{ASSEMBLY_DIR}/{sample}/"
        f"{sample}.final.contigs.fa"
    )

    required = [
        bowtie_log,
        flagstat,
        depth,
        bam,
        time_log,
        contigs
    ]

    for filename in required:
        if not os.path.isfile(filename):
            raise FileNotFoundError(
                "Missing file: {}".format(filename)
            )

    # --------------------------------------------------------
    # Bowtie2 overall alignment rate
    # --------------------------------------------------------

    overall = None

    with open(bowtie_log) as f:
        for line in f:
            m = re.search(
                r"([\d.]+)% overall alignment rate",
                line
            )

            if m:
                overall = float(m.group(1))

    # --------------------------------------------------------
    # samtools flagstat
    # --------------------------------------------------------

    total_reads = None
    mapped_reads = None
    properly_paired = None
    singletons = None

    with open(flagstat) as f:

        for line in f:

            if " in total " in line:
                total_reads = int(line.split()[0])

            elif " primary mapped " in line:
                mapped_reads = int(line.split()[0])

            elif " properly paired " in line:
                m = re.search(
                    r"\(([\d.]+)%",
                    line
                )

                if m:
                    properly_paired = float(
                        m.group(1)
                    )

            elif " singletons " in line:
                m = re.search(
                    r"\(([\d.]+)%",
                    line
                )

                if m:
                    singletons = float(
                        m.group(1)
                    )

    # --------------------------------------------------------
    # Assembly contig number
    # --------------------------------------------------------

    assembly_contigs = 0

    with open(contigs) as f:
        for line in f:
            if line.startswith(">"):
                assembly_contigs += 1

    # --------------------------------------------------------
    # Depth rows
    # --------------------------------------------------------

    with open(depth) as f:
        depth_lines = sum(1 for _ in f)

    depth_rows = depth_lines - 1

    depth_complete = (
        "YES"
        if depth_rows == assembly_contigs
        else "NO"
    )

    # --------------------------------------------------------
    # BAM size
    # --------------------------------------------------------

    bam_gib = (
        os.path.getsize(bam)
        / 1024
        / 1024
        / 1024
    )

    # --------------------------------------------------------
    # Time / RAM / CPU
    # --------------------------------------------------------

    elapsed_sec = None
    maxrss_kb = None
    cpu_percent = None

    with open(time_log) as f:

        for line in f:

            line = line.strip()

            if line.startswith(
                "Elapsed (wall clock) time"
            ):
                value = line.rsplit(
                    ": ", 1
                )[-1]

                elapsed_sec = parse_elapsed(
                    value
                )

            elif line.startswith(
                "Maximum resident set size (kbytes)"
            ):
                maxrss_kb = int(
                    line.rsplit(
                        ":", 1
                    )[-1].strip()
                )

            elif line.startswith(
                "Percent of CPU this job got"
            ):
                cpu_percent = float(
                    line.rsplit(
                        ":", 1
                    )[-1]
                    .replace("%", "")
                    .strip()
                )

    rows.append({
        "Sample": sample,
        "Overall_alignment_percent": overall,
        "Properly_paired_percent": properly_paired,
        "Singletons_percent": singletons,
        "Mapped_reads": mapped_reads,
        "Total_reads": total_reads,
        "Assembly_contigs": assembly_contigs,
        "Depth_rows": depth_rows,
        "Depth_complete": depth_complete,
        "BAM_GiB": bam_gib,

        "Runtime_min":
            elapsed_sec / 60
            if elapsed_sec is not None
            else None,

        "Runtime_hour":
            elapsed_sec / 3600
            if elapsed_sec is not None
            else None,

        "MaxRSS_GiB":
            maxrss_kb / 1024 / 1024
            if maxrss_kb is not None
            else None,

        "CPU_percent": cpu_percent
    })


with open(OUTFILE, "w") as out:

    out.write("\t".join(columns) + "\n")

    for row in rows:

        values = []

        for col in columns:

            value = row[col]

            if value is None:
                values.append("NA")

            elif isinstance(value, float):
                values.append(
                    "{:.3f}".format(value)
                )

            else:
                values.append(str(value))

        out.write(
            "\t".join(values) + "\n"
        )


print("Generated: {}".format(OUTFILE))
print("Samples: {}".format(len(rows)))
