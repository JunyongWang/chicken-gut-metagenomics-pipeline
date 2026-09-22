import os
import re
import glob

results = []

for logfile in glob.glob("M*/M*.bowtie2.log"):

    sample = os.path.basename(logfile).replace(".bowtie2.log", "")
    samlog = f"{sample}/{sample}.samtools_fastq.log"

    # --------------------------------------------------------
    # Bowtie2 log
    # --------------------------------------------------------

    with open(logfile) as f:
        text = f.read()

    # Example:
    # 20461698 reads; of these:
    m = re.search(r"^(\d+) reads; of these:", text, re.M)

    if not m:
        raise RuntimeError(f"Cannot parse clean pairs from {logfile}")

    clean_pairs = int(m.group(1))

    # Example:
    # 0.17% overall alignment rate
    m = re.search(r"([\d.]+)% overall alignment rate", text)

    if not m:
        raise RuntimeError(f"Cannot parse alignment rate from {logfile}")

    bowtie2_alignment_pct = float(m.group(1))

    # --------------------------------------------------------
    # samtools fastq log
    # --------------------------------------------------------

    if not os.path.exists(samlog):
        raise RuntimeError(f"Missing {samlog}")

    with open(samlog) as f:
        samtext = f.read()

    # Example:
    # processed 40854330 reads
    m = re.search(r"processed (\d+) reads", samtext)

    if not m:
        raise RuntimeError(f"Cannot parse processed reads from {samlog}")

    dehost_reads = int(m.group(1))

    if dehost_reads % 2 != 0:
        raise RuntimeError(
            f"Odd number of dehost reads for {sample}: {dehost_reads}"
        )

    dehost_pairs = dehost_reads // 2

    # --------------------------------------------------------
    # Calculate host removal
    # --------------------------------------------------------

    host_removed_pairs = clean_pairs - dehost_pairs

    host_removed_pct = (
        host_removed_pairs / clean_pairs * 100
        if clean_pairs else 0
    )

    dehost_retention_pct = (
        dehost_pairs / clean_pairs * 100
        if clean_pairs else 0
    )

    results.append([
        sample,
        clean_pairs,
        dehost_pairs,
        host_removed_pairs,
        host_removed_pct,
        dehost_retention_pct,
        bowtie2_alignment_pct
    ])


# Natural numeric order: M1, M2, M3 ... M61
def sample_number(row):
    m = re.search(r"\d+", row[0])
    return int(m.group()) if m else 999999


results.sort(key=sample_number)


# ------------------------------------------------------------
# Output
# ------------------------------------------------------------

print(
    "Sample\t"
    "Clean_pairs\t"
    "Dehost_pairs\t"
    "Host_removed_pairs\t"
    "Host_removed_pct\t"
    "Dehost_retention_pct\t"
    "Bowtie2_alignment_pct"
)

for row in results:
    print(
        f"{row[0]}\t"
        f"{row[1]}\t"
        f"{row[2]}\t"
        f"{row[3]}\t"
        f"{row[4]:.3f}\t"
        f"{row[5]:.3f}\t"
        f"{row[6]:.3f}"
    )
