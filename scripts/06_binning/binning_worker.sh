#!/bin/bash
set -euo pipefail

# ============================================================
# 06 MAG binning worker - checkpoint/resume version
# MetaBAT2 + MaxBin2 + CONCOCT + MetaWRAP bin_refinement
# ============================================================

STAGE_DIR="${STAGE_DIR:-${SLURM_SUBMIT_DIR:-$PWD}}"
WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
CONDA_SH="${CONDA_SH:?Set CONDA_SH to conda.sh}"

cd "$STAGE_DIR"

source "$CONDA_SH"
conda activate mag_binning

THREADS="${SLURM_CPUS_PER_TASK:-4}"
export OMP_NUM_THREADS="$THREADS"
export OPENBLAS_NUM_THREADS="$THREADS"
export MKL_NUM_THREADS="$THREADS"

SAMPLE="${1:?ERROR: sample name required}"

ASSEMBLY="$WORK_ROOT/04_assembly/$SAMPLE/$SAMPLE.final.contigs.fa"
DEPTH="$WORK_ROOT/05_mapping_depth/$SAMPLE/$SAMPLE.contig_depth.tsv"
BAM="$WORK_ROOT/05_mapping_depth/$SAMPLE/$SAMPLE.contigs.sorted.bam"
BAI="${BAM}.bai"

OUT="$WORK_ROOT/06_binning/$SAMPLE"
CONTIGS="$OUT/${SAMPLE}.binning_contigs.min2000.fa"
METABAT_DEPTH="$OUT/${SAMPLE}.metabat_depth.min2000.tsv"
MAXBIN_ABUND="$OUT/${SAMPLE}.maxbin_abundance.min2000.tsv"

JOB_ID="${SLURM_JOB_ID:-manual}"
NODE="${SLURMD_NODENAME:-$(hostname)}"
SLURM_MEM_MB="${SLURM_MEM_PER_NODE:-unknown}"

mkdir -p "$OUT"

log_checkpoint() {
    local file="$1"
    local detail="$2"
    {
        echo "sample=$SAMPLE"
        echo "job_id=$JOB_ID"
        echo "node=$NODE"
        echo "time=$(date '+%F %T %Z')"
        echo "$detail"
    } > "$OUT/$file"
}

count_files() {
    local dir="$1"
    local pattern="$2"
    if [[ ! -d "$dir" ]]; then
        echo 0
        return 0
    fi
    find "$dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | wc -l
}

echo "============================================================"
echo "06 MAG BINNING - CHECKPOINT/RESUME"
echo "============================================================"
echo "Sample      : $SAMPLE"
echo "Node        : $NODE"
echo "Job ID      : $JOB_ID"
echo "CPUs        : $THREADS"
echo "Slurm mem   : ${SLURM_MEM_MB} MB"
echo "Assembly    : $ASSEMBLY"
echo "Depth       : $DEPTH"
echo "BAM         : $BAM"
echo "Start       : $(date)"
echo "============================================================"

# ============================================================
# Input checks
# ============================================================

for F in "$ASSEMBLY" "$DEPTH" "$BAM" "$BAI"
do
    if [[ ! -s "$F" ]]; then
        echo "ERROR: missing/empty input: $F" >&2
        exit 1
    fi
done

samtools quickcheck "$BAM"

if [[ -f "$OUT/.binning.done" ]]; then
    echo "$SAMPLE already completed (.binning.done found). SKIP."
    exit 0
fi

# ============================================================
# STEP 1
# Prepare >=2000 bp contigs.
# This step is fast and is regenerated on each resume run.
# ============================================================

echo
echo "===== STEP 1: prepare >=2000 bp contigs ====="
date

TMP_CONTIGS="${CONTIGS}.tmp.${JOB_ID}.$$"

python - "$ASSEMBLY" "$TMP_CONTIGS" <<'PY'
# -*- coding: utf-8 -*-
from __future__ import print_function
import sys

src = sys.argv[1]
dst = sys.argv[2]
minimum = 2000

fin = open(src)
fout = open(dst, "w")

header = None
seq = []
total = 0
kept = 0

def flush_record(header, seq):
    if header is None:
        return 0
    sequence = "".join(seq)
    if len(sequence) >= minimum:
        fout.write(">%s\n%s\n" % (header, sequence))
        return 1
    return 0

for line in fin:
    if line.startswith(">"):
        if header is not None:
            total += 1
            kept += flush_record(header, seq)
        header = line[1:].strip().split()[0]
        seq = []
    else:
        seq.append(line.strip())

if header is not None:
    total += 1
    kept += flush_record(header, seq)

fin.close()
fout.close()

print("Mother contigs :", total)
print(">=2000 bp      :", kept)
PY

mv -f "$TMP_CONTIGS" "$CONTIGS"

NCONTIG=$(awk '/^>/{n++} END{print n+0}' "$CONTIGS")
echo "Binning contigs = $NCONTIG"

if [[ "$NCONTIG" -lt 1000 ]]; then
    echo "ERROR: unexpectedly few >=2000 bp contigs" >&2
    exit 1
fi

# ============================================================
# STEP 2
# Prepare MetaBAT2 JGI depth subset and MaxBin2 abundance.
# This step is fast and is regenerated on each resume run.
# ============================================================

echo
echo "===== STEP 2: prepare abundance tables ====="
date

TMP_METABAT="${METABAT_DEPTH}.tmp.${JOB_ID}.$$"
TMP_MAXBIN="${MAXBIN_ABUND}.tmp.${JOB_ID}.$$"

python - "$CONTIGS" "$DEPTH" "$TMP_METABAT" "$TMP_MAXBIN" <<'PY'
# -*- coding: utf-8 -*-
from __future__ import print_function
import sys

fasta = sys.argv[1]
depth = sys.argv[2]
metabat_out = sys.argv[3]
maxbin_out = sys.argv[4]

keep = set()
for line in open(fasta):
    if line.startswith(">"):
        keep.add(line[1:].strip().split()[0])

fin = open(depth)
fmeta = open(metabat_out, "w")
fmax = open(maxbin_out, "w")

header = fin.readline()
if not header:
    raise SystemExit("ERROR: empty depth file")

fmeta.write(header)
n_meta = 0
n_max = 0

for line in fin:
    if not line.strip():
        continue

    fields = line.rstrip("\r\n").split("\t")
    if len(fields) < 4:
        continue

    contig = fields[0]
    if contig not in keep:
        continue

    fmeta.write(line)
    n_meta += 1

    fmax.write("%s\t%s\n" % (contig, fields[3]))
    n_max += 1

fin.close()
fmeta.close()
fmax.close()

print("FASTA contigs       :", len(keep))
print("MetaBAT depth rows  :", n_meta)
print("MaxBin abundance    :", n_max)

if n_meta != len(keep):
    raise SystemExit("ERROR: MetaBAT depth rows do not match FASTA contigs")
if n_max != len(keep):
    raise SystemExit("ERROR: MaxBin abundance rows do not match FASTA contigs")
PY

mv -f "$TMP_METABAT" "$METABAT_DEPTH"
mv -f "$TMP_MAXBIN" "$MAXBIN_ABUND"

echo "Depth rows:"
awk 'END{print NR-1}' "$METABAT_DEPTH"
echo "MaxBin abundance rows:"
wc -l < "$MAXBIN_ABUND"

# ============================================================
# STEP 3 - MetaBAT2
# checkpoint: .metabat2.done
# ============================================================

echo
echo "===== STEP 3: MetaBAT2 ====="
date

N_METABAT=0

if [[ -f "$OUT/.metabat2.done" ]]; then
    N_METABAT=$(count_files "$OUT/metabat2_bins" '*.fa')
    if [[ "$N_METABAT" -gt 0 ]]; then
        echo "Checkpoint found: .metabat2.done"
        echo "MetaBAT2 bins = $N_METABAT"
    else
        echo "WARNING: .metabat2.done exists but no MetaBAT2 bins found; rerunning MetaBAT2."
        rm -f "$OUT/.metabat2.done"
    fi
fi

if [[ ! -f "$OUT/.metabat2.done" ]]; then
    rm -rf "$OUT/metabat2_bins"
    mkdir -p "$OUT/metabat2_bins"
    rm -f "$OUT/.refinement.done" "$OUT/.binning.done"

    /usr/bin/time -v \
        -o "$OUT/metabat2.time.log" \
        metabat2 \
            -i "$CONTIGS" \
            -a "$METABAT_DEPTH" \
            -o "$OUT/metabat2_bins/${SAMPLE}.metabat2.bin" \
            -m 2000 \
            -s 200000 \
            -t "$THREADS" \
            --seed 42 \
            > "$OUT/metabat2.log" 2>&1

    N_METABAT=$(count_files "$OUT/metabat2_bins" '*.fa')
    echo "MetaBAT2 bins = $N_METABAT"

    if [[ "$N_METABAT" -eq 0 ]]; then
        echo "ERROR: MetaBAT2 produced zero bins" >&2
        exit 1
    fi

    log_checkpoint ".metabat2.done" "bins=$N_METABAT"
    echo "Checkpoint written: .metabat2.done"
fi

# ============================================================
# STEP 4 - MaxBin2
# checkpoint: .maxbin2.done
# ============================================================

echo
echo "===== STEP 4: MaxBin2 ====="
date

N_MAXBIN=0

if [[ -f "$OUT/.maxbin2.done" ]]; then
    N_MAXBIN=$(count_files "$OUT/maxbin2_bins" '*.fasta')
    if [[ "$N_MAXBIN" -gt 0 ]]; then
        echo "Checkpoint found: .maxbin2.done"
        echo "MaxBin2 bins = $N_MAXBIN"
    else
        echo "WARNING: .maxbin2.done exists but no MaxBin2 bins found; rerunning MaxBin2."
        rm -f "$OUT/.maxbin2.done"
    fi
fi

if [[ ! -f "$OUT/.maxbin2.done" ]]; then
    rm -rf "$OUT/maxbin2_raw" "$OUT/maxbin2_bins"
    mkdir -p "$OUT/maxbin2_raw" "$OUT/maxbin2_bins"
    rm -f "$OUT/.refinement.done" "$OUT/.binning.done"

    /usr/bin/time -v \
        -o "$OUT/maxbin2.time.log" \
        run_MaxBin.pl \
            -contig "$CONTIGS" \
            -abund "$MAXBIN_ABUND" \
            -out "$OUT/maxbin2_raw/${SAMPLE}.maxbin2" \
            -thread "$THREADS" \
            -min_contig_length 2000 \
            -markerset 107 \
            > "$OUT/maxbin2.log" 2>&1

    shopt -s nullglob
    MAXBIN_FILES=( "$OUT"/maxbin2_raw/${SAMPLE}.maxbin2.*.fasta )

    if [[ "${#MAXBIN_FILES[@]}" -eq 0 ]]; then
        echo "ERROR: MaxBin2 produced zero bins" >&2
        exit 1
    fi

    for F in "${MAXBIN_FILES[@]}"
    do
        cp "$F" "$OUT/maxbin2_bins/"
    done

    N_MAXBIN=$(count_files "$OUT/maxbin2_bins" '*.fasta')
    echo "MaxBin2 bins = $N_MAXBIN"

    if [[ "$N_MAXBIN" -eq 0 ]]; then
        echo "ERROR: MaxBin2 produced zero bins" >&2
        exit 1
    fi

    log_checkpoint ".maxbin2.done" "bins=$N_MAXBIN"
    echo "Checkpoint written: .maxbin2.done"
fi

# ============================================================
# STEP 5 - CONCOCT
# checkpoint: .concoct.done
# ============================================================

echo
echo "===== STEP 5: CONCOCT ====="
date

N_CONCOCT=0

if [[ -f "$OUT/.concoct.done" ]]; then
    N_CONCOCT=$(count_files "$OUT/concoct_bins" '*.fa')
    if [[ "$N_CONCOCT" -gt 0 ]]; then
        echo "Checkpoint found: .concoct.done"
        echo "CONCOCT bins = $N_CONCOCT"
    else
        echo "WARNING: .concoct.done exists but no CONCOCT bins found; rerunning CONCOCT."
        rm -f "$OUT/.concoct.done"
    fi
fi

if [[ ! -f "$OUT/.concoct.done" ]]; then
    rm -rf "$OUT/concoct_work" "$OUT/concoct_bins"
    mkdir -p "$OUT/concoct_work" "$OUT/concoct_bins"
    rm -f "$OUT/.refinement.done" "$OUT/.binning.done"

    CWORK="$OUT/concoct_work"

    cut_up_fasta.py \
        "$CONTIGS" \
        -c 10000 \
        -o 0 \
        -m \
        -b "$CWORK/${SAMPLE}.contigs_10K.bed" \
        > "$CWORK/${SAMPLE}.contigs_10K.fa"

    concoct_coverage_table.py \
        "$CWORK/${SAMPLE}.contigs_10K.bed" \
        "$BAM" \
        > "$CWORK/${SAMPLE}.coverage.tsv"

    /usr/bin/time -v \
        -o "$OUT/concoct.time.log" \
        concoct \
            --composition_file "$CWORK/${SAMPLE}.contigs_10K.fa" \
            --coverage_file "$CWORK/${SAMPLE}.coverage.tsv" \
            -c 400 \
            -k 4 \
            -t "$THREADS" \
            -l 1000 \
            -s 42 \
            -b "$CWORK/" \
            > "$OUT/concoct.log" 2>&1

    CLUSTER="$CWORK/clustering_gt1000.csv"
    if [[ ! -s "$CLUSTER" ]]; then
        echo "ERROR: CONCOCT clustering output missing" >&2
        exit 1
    fi

    merge_cutup_clustering.py \
        "$CLUSTER" \
        > "$CWORK/${SAMPLE}.clustering_merged.csv"

    extract_fasta_bins.py \
        "$CONTIGS" \
        "$CWORK/${SAMPLE}.clustering_merged.csv" \
        --output_path "$OUT/concoct_bins"

    shopt -s nullglob
    CONCOCT_FILES=( "$OUT"/concoct_bins/*.fa )

    if [[ "${#CONCOCT_FILES[@]}" -eq 0 ]]; then
        echo "ERROR: CONCOCT produced zero bins" >&2
        exit 1
    fi

    for F in "${CONCOCT_FILES[@]}"
    do
        BASE=$(basename "$F")
        if [[ "$BASE" != "$SAMPLE.concoct.bin."* ]]; then
            mv "$F" "$OUT/concoct_bins/${SAMPLE}.concoct.bin.${BASE}"
        fi
    done

    N_CONCOCT=$(count_files "$OUT/concoct_bins" '*.fa')
    echo "CONCOCT bins = $N_CONCOCT"

    if [[ "$N_CONCOCT" -eq 0 ]]; then
        echo "ERROR: CONCOCT produced zero bins" >&2
        exit 1
    fi

    log_checkpoint ".concoct.done" "bins=$N_CONCOCT"
    echo "Checkpoint written: .concoct.done"
fi

# ============================================================
# STEP 6 - MetaWRAP bin refinement
# Candidate-retention threshold at this stage: completeness >=50,
# contamination <=10. Formal MAG QC is done later with CheckM2.
# checkpoint: .refinement.done
# ============================================================

echo
echo "===== STEP 6: MetaWRAP bin_refinement ====="
date

FINAL="$OUT/refinement/metawrap_50_10_bins"
N_REFINED=0

if [[ -f "$OUT/.refinement.done" ]]; then
    N_REFINED=$(count_files "$FINAL" '*.fa')
    if [[ "$N_REFINED" -gt 0 ]]; then
        echo "Checkpoint found: .refinement.done"
        echo "Refined bins = $N_REFINED"
    else
        echo "WARNING: .refinement.done exists but final bins are missing; rerunning refinement."
        rm -f "$OUT/.refinement.done"
    fi
fi

if [[ ! -f "$OUT/.refinement.done" ]]; then
    rm -rf "$OUT/refinement"
    rm -f "$OUT/.binning.done"

    /usr/bin/time -v \
        -o "$OUT/refinement.time.log" \
        metawrap bin_refinement \
            -o "$OUT/refinement" \
            -t "$THREADS" \
            -m 48 \
            -c 50 \
            -x 10 \
            -A "$OUT/metabat2_bins" \
            -B "$OUT/maxbin2_bins" \
            -C "$OUT/concoct_bins" \
            --quick \
            > "$OUT/refinement.log" 2>&1

    if [[ ! -d "$FINAL" ]]; then
        echo "ERROR: MetaWRAP final bin folder missing" >&2
        exit 1
    fi

    N_REFINED=$(count_files "$FINAL" '*.fa')
    echo "Refined bins = $N_REFINED"

    if [[ "$N_REFINED" -eq 0 ]]; then
        echo "ERROR: zero refined bins passed 50/10" >&2
        exit 1
    fi

    log_checkpoint ".refinement.done" "bins=$N_REFINED"
    echo "Checkpoint written: .refinement.done"
fi

# ============================================================
# STEP 7 - Final bins with sample prefix
# ============================================================

echo
echo "===== STEP 7: prepare final refined bins ====="
date

rm -rf "$OUT/refined_bins"
mkdir -p "$OUT/refined_bins"

shopt -s nullglob
FINAL_FILES=( "$FINAL"/*.fa )

if [[ "${#FINAL_FILES[@]}" -eq 0 ]]; then
    echo "ERROR: no refined bins found in $FINAL" >&2
    exit 1
fi

for F in "${FINAL_FILES[@]}"
do
    BASE=$(basename "$F")
    cp "$F" "$OUT/refined_bins/${SAMPLE}.refined.${BASE}"
done

N_FINAL=$(count_files "$OUT/refined_bins" '*.fa')
if [[ "$N_FINAL" -ne "$N_REFINED" ]]; then
    echo "ERROR: final copied-bin count ($N_FINAL) != refined-bin count ($N_REFINED)" >&2
    exit 1
fi

# ============================================================
# STEP 8 - Summary + final completion marker
# ============================================================

echo
echo "===== STEP 8: summary ====="
date

SUMMARY="$OUT/${SAMPLE}.binning_summary.tsv"

{
    echo -e "Sample\tInput_contigs_ge2000\tMetaBAT2_bins\tMaxBin2_bins\tCONCOCT_bins\tRefined_bins"
    echo -e "${SAMPLE}\t${NCONTIG}\t${N_METABAT}\t${N_MAXBIN}\t${N_CONCOCT}\t${N_REFINED}"
} > "$SUMMARY"

log_checkpoint ".binning.done" "refined_bins=$N_REFINED"

echo
echo "============================================================"
echo "BINNING FINISHED"
echo "============================================================"
cat "$SUMMARY"
echo
echo "Final bins: $OUT/refined_bins"
echo "Finish: $(date)"
echo "============================================================"
