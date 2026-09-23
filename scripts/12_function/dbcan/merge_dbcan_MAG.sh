#!/bin/bash

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/12_function}"
cd "$STAGE_DIR"

INDIR="dbcan/11B/results"
OUTDIR="dbcan/11B/final"

OVERVIEW="$OUTDIR/MAG_dbcan_overview.tsv"
RECOMMENDED="$OUTDIR/MAG_dbcan_recommended.tsv"
SUMMARY="$OUTDIR/MAG_dbcan_summary.tsv"

mkdir -p "$OUTDIR"

rm -f \
  "$OVERVIEW" \
  "$RECOMMENDED" \
  "$SUMMARY" \
  "$OUTDIR/.merge.done"

TOTAL_INPUT=0
TOTAL_OVERVIEW=0
TOTAL_RECOMMENDED=0
FIRST=1

for i in 001 002 003 004 005 006 007
do
    D="$INDIR/chunk_${i}"
    O="$D/overview.tsv"
    Q="$D/qc.tsv"

    [[ -f "$D/.dbcan.done" ]]
    [[ -s "$O" ]]
    [[ -s "$Q" ]]

    INPUT_N=$(awk -F'\t' 'NR==2{print $2}' "$Q")
    OVERVIEW_N=$(awk -F'\t' 'NR==2{print $3}' "$Q")
    REC_N=$(awk -F'\t' 'NR==2{print $4}' "$Q")

    TOTAL_INPUT=$((TOTAL_INPUT + INPUT_N))
    TOTAL_OVERVIEW=$((TOTAL_OVERVIEW + OVERVIEW_N))
    TOTAL_RECOMMENDED=$((TOTAL_RECOMMENDED + REC_N))

    if [[ "$FIRST" -eq 1 ]]; then
        head -1 "$O" > "$OVERVIEW"
        head -1 "$O" > "$RECOMMENDED"
        FIRST=0
    fi

    tail -n +2 "$O" >> "$OVERVIEW"

    awk -F'\t' '
    NR>1 && $6+0 >= 2
    ' "$O" >> "$RECOMMENDED"
done

[[ "$TOTAL_INPUT" -eq 688771 ]]

MERGED_OVERVIEW=$(
    awk 'NR>1 && NF>0 {n++} END{print n+0}' "$OVERVIEW"
)

MERGED_RECOMMENDED=$(
    awk 'NR>1 && NF>0 {n++} END{print n+0}' "$RECOMMENDED"
)

[[ "$MERGED_OVERVIEW" -eq "$TOTAL_OVERVIEW" ]]
[[ "$MERGED_RECOMMENDED" -eq "$TOTAL_RECOMMENDED" ]]

UNIQUE_OVERVIEW=$(
    awk -F'\t' 'NR>1 {print $1}' "$OVERVIEW" \
    | LC_ALL=C sort -u \
    | wc -l
)

UNIQUE_RECOMMENDED=$(
    awk -F'\t' 'NR>1 {print $1}' "$RECOMMENDED" \
    | LC_ALL=C sort -u \
    | wc -l
)

[[ "$UNIQUE_OVERVIEW" -eq "$MERGED_OVERVIEW" ]]
[[ "$UNIQUE_RECOMMENDED" -eq "$MERGED_RECOMMENDED" ]]

{
    printf 'metric\tvalue\n'
    printf 'input_proteins\t%s\n' "$TOTAL_INPUT"
    printf 'overview_genes\t%s\n' "$TOTAL_OVERVIEW"
    printf 'recommended_cazyme_genes\t%s\n' "$TOTAL_RECOMMENDED"

    awk \
      -v n="$TOTAL_OVERVIEW" \
      -v d="$TOTAL_INPUT" \
      'BEGIN{printf "overview_rate_percent\t%.4f\n",100*n/d}'

    awk \
      -v n="$TOTAL_RECOMMENDED" \
      -v d="$TOTAL_INPUT" \
      'BEGIN{printf "recommended_rate_percent\t%.4f\n",100*n/d}'

    printf 'dbcan_version\t5.2.9\n'
    printf 'recommendation_rule\t#ofTools>=2\n'
} > "$SUMMARY"

touch "$OUTDIR/.merge.done"

cat "$SUMMARY"
ls -lh "$OUTDIR"
