#!/usr/bin/env python3

import os
import statistics

SAMPLES_FILE = os.environ.get("SAMPLES_FILE", "samples.txt")
OUTFILE = os.environ.get("OUTFILE", "assembly_QC_summary.tsv")


def parse_elapsed(value):
    """
    GNU time elapsed formats:
      h:mm:ss
      m:ss
    Return seconds.
    """
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

    else:
        return float(parts[0])


def parse_seqkit_stats(filename):

    with open(filename) as f:
        lines = [x.strip() for x in f if x.strip()]

    if len(lines) < 2:
        raise RuntimeError(
            "Invalid seqkit stats file: {}".format(filename)
        )

    header = lines[0].split()
    values = lines[1].split()

    stats = dict(zip(header, values))

    def num(x):
        return x.replace(",", "")

    return {
        "Contig_count": int(num(stats["num_seqs"])),
        "Assembly_size_bp": int(num(stats["sum_len"])),
        "Min_contig_bp": int(num(stats["min_len"])),
        "Average_contig_bp": float(num(stats["avg_len"])),
        "Max_contig_bp": int(num(stats["max_len"])),
        "GC_percent": float(num(stats["GC(%)"]))
    }


def parse_length_summary(filename):

    result = {}

    with open(filename) as f:
        next(f)

        for line in f:
            if not line.strip():
                continue

            threshold, count = line.rstrip().split("\t")

            result[threshold] = int(count)

    return result


def parse_nx(filename):

    result = {}

    with open(filename) as f:
        next(f)

        for line in f:
            if not line.strip():
                continue

            metric, value = line.rstrip().split("\t")
            result[metric] = int(value)

    return result


def parse_time(filename):

    elapsed_sec = None
    maxrss_kb = None
    cpu_percent = None

    with open(filename) as f:

        for line in f:

            line = line.strip()

            if line.startswith(
                "Elapsed (wall clock) time"
            ):
                value = line.rsplit(": ", 1)[-1]
                elapsed_sec = parse_elapsed(value)

            elif line.startswith(
                "Maximum resident set size (kbytes)"
            ):
                maxrss_kb = int(
                    line.rsplit(":", 1)[-1].strip()
                )

            elif line.startswith(
                "Percent of CPU this job got"
            ):
                value = (
                    line.rsplit(":", 1)[-1]
                    .strip()
                    .replace("%", "")
                )

                cpu_percent = float(value)

    return {
        "Runtime_min":
            elapsed_sec / 60
            if elapsed_sec is not None else None,

        "Runtime_hour":
            elapsed_sec / 3600
            if elapsed_sec is not None else None,

        "MaxRSS_GiB":
            maxrss_kb / 1024 / 1024
            if maxrss_kb is not None else None,

        "CPU_percent":
            cpu_percent
    }


# ============================================================
# Samples
# ============================================================

with open(SAMPLES_FILE) as f:
    samples = [
        x.strip()
        for x in f
        if x.strip()
    ]


columns = [
    "Sample",
    "Contig_count",
    "Assembly_size_bp",
    "Assembly_size_Mb",
    "Min_contig_bp",
    "Average_contig_bp",
    "Max_contig_bp",
    "N50_bp",
    "N50_num",
    "N90_bp",
    "N90_num",
    "GC_percent",
    "Contigs_ge500",
    "Contigs_ge1000",
    "Contigs_ge1500",
    "Contigs_ge2000",
    "Contigs_ge5000",
    "Contigs_ge10000",
    "Runtime_min",
    "Runtime_hour",
    "MaxRSS_GiB",
    "CPU_percent"
]


rows = []


for sample in samples:

    stats_file = (
        "{0}/{0}.contig_stats.txt"
        .format(sample)
    )

    length_file = (
        "{0}/{0}.contig_length_summary.tsv"
        .format(sample)
    )

    nx_file = (
        "{0}/{0}.N50_N90.tsv"
        .format(sample)
    )

    time_file = (
        "{0}/{0}.megahit.time.log"
        .format(sample)
    )

    required = [
        stats_file,
        length_file,
        nx_file,
        time_file
    ]

    for filename in required:
        if not os.path.isfile(filename):
            raise FileNotFoundError(
                "Missing file: {}".format(filename)
            )

    stats = parse_seqkit_stats(stats_file)
    lengths = parse_length_summary(length_file)
    nx = parse_nx(nx_file)
    time_stats = parse_time(time_file)

    row = {
        "Sample": sample,

        **stats,

        "Assembly_size_Mb":
            stats["Assembly_size_bp"] / 1e6,

        "N50_bp":
            nx["N50"],

        "N50_num":
            nx["N50_num"],

        "N90_bp":
            nx["N90"],

        "N90_num":
            nx["N90_num"],

        "Contigs_ge500":
            lengths[">=500_bp"],

        "Contigs_ge1000":
            lengths[">=1000_bp"],

        "Contigs_ge1500":
            lengths[">=1500_bp"],

        "Contigs_ge2000":
            lengths[">=2000_bp"],

        "Contigs_ge5000":
            lengths[">=5000_bp"],

        "Contigs_ge10000":
            lengths[">=10000_bp"],

        **time_stats
    }

    rows.append(row)


# ============================================================
# Write summary
# ============================================================

with open(OUTFILE, "w") as out:

    out.write("\t".join(columns) + "\n")

    for row in rows:

        values = []

        for column in columns:

            value = row[column]

            if value is None:
                values.append("NA")

            elif isinstance(value, float):
                values.append("{:.3f}".format(value))

            else:
                values.append(str(value))

        out.write(
            "\t".join(values) + "\n"
        )


print("Generated: {}".format(OUTFILE))
print("Samples: {}".format(len(rows)))
