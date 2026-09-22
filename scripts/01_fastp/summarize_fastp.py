import json
import glob
import os

files = sorted(glob.glob("M*/M*.fastp.json"))

header = [
    "Sample",
    "Raw_reads",
    "Clean_reads",
    "Retention_pct",
    "Raw_Q20_pct",
    "Raw_Q30_pct",
    "Clean_Q20_pct",
    "Clean_Q30_pct",
    "Raw_GC_pct",
    "Clean_GC_pct",
    "Low_quality_reads",
    "Too_many_N_reads",
    "Too_short_reads",
    "Low_complexity_reads",
    "Adapter_trimmed_reads",
    "Duplication_pct",
    "Insert_size_peak"
]

print("\t".join(header))

for f in files:
    sample = os.path.basename(f).replace(".fastp.json", "")

    with open(f) as fh:
        d = json.load(fh)

    before = d["summary"]["before_filtering"]
    after = d["summary"]["after_filtering"]
    filt = d.get("filtering_result", {})
    adapter = d.get("adapter_cutting", {})
    duplication = d.get("duplication", {})
    insert = d.get("insert_size", {})

    raw_reads = before["total_reads"]
    clean_reads = after["total_reads"]

    retention = clean_reads / raw_reads * 100 if raw_reads else 0

    row = [
        sample,
        str(raw_reads),
        str(clean_reads),
        f"{retention:.2f}",
        f"{before.get('q20_rate', 0) * 100:.2f}",
        f"{before.get('q30_rate', 0) * 100:.2f}",
        f"{after.get('q20_rate', 0) * 100:.2f}",
        f"{after.get('q30_rate', 0) * 100:.2f}",
        f"{before.get('gc_content', 0) * 100:.2f}",
        f"{after.get('gc_content', 0) * 100:.2f}",
        str(filt.get("low_quality_reads", 0)),
        str(filt.get("too_many_N_reads", 0)),
        str(filt.get("too_short_reads", 0)),
        str(filt.get("low_complexity_reads", 0)),
        str(adapter.get("adapter_trimmed_reads", 0)),
        f"{duplication.get('rate', 0) * 100:.2f}",
        str(insert.get("peak", 0))
    ]

    print("\t".join(row))
