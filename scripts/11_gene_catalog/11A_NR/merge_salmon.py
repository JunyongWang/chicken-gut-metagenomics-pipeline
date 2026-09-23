#!/usr/bin/env python3

from pathlib import Path
from contextlib import ExitStack
import os
import sys

BASE = Path(os.environ.get("STAGE_DIR", "."))
SAMPLE_FILE = Path(os.environ.get("SAMPLE_LIST", BASE / "samples.txt"))
QUANT_DIR = BASE / "salmon" / "quant"
OUTDIR = BASE / "salmon" / "matrices"

EXPECTED_GENES = 13151701

OUTDIR.mkdir(parents=True, exist_ok=True)

samples = [
    x.strip()
    for x in SAMPLE_FILE.read_text().splitlines()
    if x.strip()
]

if len(samples) != 60:
    sys.exit(f"ERROR: expected 60 samples, got {len(samples)}")

quant_files = [
    QUANT_DIR / s / "quant.sf"
    for s in samples
]

for s, f in zip(samples, quant_files):
    if not f.is_file() or f.stat().st_size == 0:
        sys.exit(f"ERROR: missing quant.sf for {s}: {f}")

tpm_tmp = OUTDIR / "Gene_TPM.tsv.tmp"
reads_tmp = OUTDIR / "Gene_NumReads.tsv.tmp"

tpm_final = OUTDIR / "Gene_TPM.tsv"
reads_final = OUTDIR / "Gene_NumReads.tsv"

for f in [tpm_tmp, reads_tmp]:
    if f.exists():
        f.unlink()

with ExitStack() as stack:

    handles = [
        stack.enter_context(open(f, "r", buffering=1024 * 1024))
        for f in quant_files
    ]

    tpm_out = stack.enter_context(
        open(tpm_tmp, "w", buffering=1024 * 1024)
    )

    reads_out = stack.enter_context(
        open(reads_tmp, "w", buffering=1024 * 1024)
    )

    # --------------------------------------------------------
    # Validate headers
    # --------------------------------------------------------

    expected_header = [
        "Name",
        "Length",
        "EffectiveLength",
        "TPM",
        "NumReads"
    ]

    for sample, h in zip(samples, handles):
        header = h.readline().rstrip("\n").split("\t")

        if header != expected_header:
            sys.exit(
                f"ERROR: unexpected quant.sf header for {sample}: {header}"
            )

    tpm_out.write("Gene\t" + "\t".join(samples) + "\n")
    reads_out.write("Gene\t" + "\t".join(samples) + "\n")

    # --------------------------------------------------------
    # Stream all 60 quant.sf files in parallel
    # --------------------------------------------------------

    n = 0

    while True:

        lines = [h.readline() for h in handles]

        if all(line == "" for line in lines):
            break

        if any(line == "" for line in lines):
            sys.exit(
                f"ERROR: quant.sf files ended at different positions "
                f"near gene row {n + 1}"
            )

        fields = [line.rstrip("\n").split("\t") for line in lines]

        for i, row in enumerate(fields):
            if len(row) != 5:
                sys.exit(
                    f"ERROR: malformed row in {samples[i]} "
                    f"at gene row {n + 1}"
                )

        gene = fields[0][0]

        # verify all samples have exactly the same gene at this row
        for i in range(1, len(fields)):
            if fields[i][0] != gene:
                sys.exit(
                    f"ERROR: gene order mismatch at row {n + 1}: "
                    f"{samples[0]}={gene}, "
                    f"{samples[i]}={fields[i][0]}"
                )

        tpms = [row[3] for row in fields]
        reads = [row[4] for row in fields]

        tpm_out.write(gene + "\t" + "\t".join(tpms) + "\n")
        reads_out.write(gene + "\t" + "\t".join(reads) + "\n")

        n += 1

        if n % 1000000 == 0:
            print(f"Processed {n:,} genes", flush=True)

if n != EXPECTED_GENES:
    sys.exit(
        f"ERROR: expected {EXPECTED_GENES} genes, got {n}"
    )

tpm_tmp.replace(tpm_final)
reads_tmp.replace(reads_final)

print("")
print(f"Samples : {len(samples)}")
print(f"Genes   : {n}")
print(f"TPM     : {tpm_final}")
print(f"Reads   : {reads_final}")
print("Done.")
