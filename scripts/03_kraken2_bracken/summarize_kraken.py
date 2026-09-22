import os
import re

samples = []

samples_file = os.environ.get("SAMPLES_FILE", "samples.txt")

with open(samples_file) as f:
    for line in f:
        s = line.strip()
        if s:
            samples.append(s)

print(
    "Sample\tTotal_pairs\tClassified_pairs\tUnclassified_pairs\t"
    "Classified_pct\tUnclassified_pct\t"
    "Bacteria_pct\tArchaea_pct\tViruses_pct\tEukaryota_pct\t"
    "Species_count\tGenus_count"
)

for sample in samples:

    log = f"{sample}/{sample}.kraken.log"
    report = f"{sample}/{sample}.kraken.report"
    species = f"{sample}/{sample}.S.bracken"
    genus = f"{sample}/{sample}.G.bracken"

    # --------------------------------------------------------
    # Kraken log
    # --------------------------------------------------------

    with open(log) as f:
        text = f.read()

    m = re.search(r"(\d+) sequences .* processed", text)
    if not m:
        raise RuntimeError(f"Cannot parse total reads: {log}")
    total = int(m.group(1))

    m = re.search(
        r"(\d+) sequences classified \(([\d.]+)%\)",
        text
    )
    if not m:
        raise RuntimeError(f"Cannot parse classified reads: {log}")

    classified = int(m.group(1))
    classified_pct = float(m.group(2))

    m = re.search(
        r"(\d+) sequences unclassified \(([\d.]+)%\)",
        text
    )
    if not m:
        raise RuntimeError(f"Cannot parse unclassified reads: {log}")

    unclassified = int(m.group(1))
    unclassified_pct = float(m.group(2))

    # --------------------------------------------------------
    # Kraken report: domain percentages
    # --------------------------------------------------------

    domain_pct = {
        "Bacteria": 0.0,
        "Archaea": 0.0,
        "Viruses": 0.0,
        "Eukaryota": 0.0
    }

    with open(report) as f:
        for line in f:

            fields = line.rstrip("\n").split("\t")

            if len(fields) < 6:
                continue

            pct = float(fields[0])
            rank = fields[3]
            name = fields[5].strip()

            if rank == "D" and name in domain_pct:
                domain_pct[name] = pct

    # --------------------------------------------------------
    # Bracken taxa counts
    # --------------------------------------------------------

    def count_taxa(filename):
        with open(filename) as f:
            n = sum(1 for _ in f)
        return max(n - 1, 0)  # remove header

    species_count = count_taxa(species)
    genus_count = count_taxa(genus)

    print(
        f"{sample}\t"
        f"{total}\t"
        f"{classified}\t"
        f"{unclassified}\t"
        f"{classified_pct:.2f}\t"
        f"{unclassified_pct:.2f}\t"
        f"{domain_pct['Bacteria']:.2f}\t"
        f"{domain_pct['Archaea']:.2f}\t"
        f"{domain_pct['Viruses']:.2f}\t"
        f"{domain_pct['Eukaryota']:.2f}\t"
        f"{species_count}\t"
        f"{genus_count}"
    )
