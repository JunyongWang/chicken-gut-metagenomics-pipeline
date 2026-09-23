#!/bin/bash
#SBATCH --job-name=merge_MAG_genes
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=logs/merge_MAG_genes_%j.out
#SBATCH --error=logs/merge_MAG_genes_%j.err

set -euo pipefail

WORK_ROOT="${WORK_ROOT:?Set WORK_ROOT to the pipeline work directory}"
STAGE_DIR="${STAGE_DIR:-$WORK_ROOT/11_gene_catalog/11B_MAG}"
MAG_LIST="${MAG_LIST:?Set MAG_LIST to the ordered 374-MAG manifest}"

cd "$STAGE_DIR"

OUTDIR="$STAGE_DIR/catalog"

FFN="$OUTDIR/MAG_gene_catalog.ffn"
FAA="$OUTDIR/MAG_gene_catalog.faa"
MAP="$OUTDIR/MAG_gene_to_MAG.tsv"
SUMMARY="$OUTDIR/MAG_prodigal_summary.tsv"

FFN_TMP="$FFN.tmp"
FAA_TMP="$FAA.tmp"
MAP_TMP="$MAP.tmp"
SUMMARY_TMP="$SUMMARY.tmp"

DONE="$OUTDIR/.merge_MAG_genes.done"

mkdir -p "$OUTDIR"

echo "============================================================"
echo "Merge MAG gene catalogs"
echo "Node  : $(hostname)"
echo "Start : $(date)"
echo "============================================================"

# ------------------------------------------------------------
# clean previous incomplete files
# ------------------------------------------------------------

rm -f \
    "$FFN_TMP" \
    "$FAA_TMP" \
    "$MAP_TMP" \
    "$SUMMARY_TMP" \
    "$DONE"

# ------------------------------------------------------------
# headers
# ------------------------------------------------------------

printf "Gene\tMAG\n" > "$MAP_TMP"

printf "MAG\tGenes\tProteins\n" > "$SUMMARY_TMP"

TOTAL_GENES=0
TOTAL_MAGS=0

# ------------------------------------------------------------
# merge 374 MAGs
# ------------------------------------------------------------

while read -r MAG
do

    MAG_FFN="prodigal/$MAG/${MAG}.genes.ffn"
    MAG_FAA="prodigal/$MAG/${MAG}.genes.faa"

    if [[ ! -s "$MAG_FFN" ]]; then
        echo "ERROR: missing FFN: $MAG_FFN"
        exit 1
    fi

    if [[ ! -s "$MAG_FAA" ]]; then
        echo "ERROR: missing FAA: $MAG_FAA"
        exit 1
    fi

    N_FFN=$(grep -c '^>' "$MAG_FFN")
    N_FAA=$(grep -c '^>' "$MAG_FAA")

    if [[ "$N_FFN" -eq 0 ]]; then
        echo "ERROR: zero genes in $MAG"
        exit 1
    fi

    if [[ "$N_FFN" -ne "$N_FAA" ]]; then
        echo "ERROR: FFN/FAA count mismatch in $MAG"
        echo "FFN = $N_FFN"
        echo "FAA = $N_FAA"
        exit 1
    fi

    # --------------------------------------------------------
    # Check FFN and FAA gene IDs are identical
    # --------------------------------------------------------

    if ! diff -q \
        <(grep '^>' "$MAG_FFN" | awk '{gsub(/^>/,"",$1); print $1}') \
        <(grep '^>' "$MAG_FAA" | awk '{gsub(/^>/,"",$1); print $1}') \
        >/dev/null
    then
        echo "ERROR: FFN/FAA gene IDs differ in $MAG"
        exit 1
    fi

    # --------------------------------------------------------
    # concatenate
    # --------------------------------------------------------

    cat "$MAG_FFN" >> "$FFN_TMP"
    cat "$MAG_FAA" >> "$FAA_TMP"

    # --------------------------------------------------------
    # gene -> MAG mapping
    # --------------------------------------------------------

    awk -v mag="$MAG" '
    /^>/ {
        id=$1
        sub(/^>/,"",id)
        print id "\t" mag
    }
    ' "$MAG_FFN" >> "$MAP_TMP"

    printf "%s\t%s\t%s\n" \
        "$MAG" "$N_FFN" "$N_FAA" \
        >> "$SUMMARY_TMP"

    TOTAL_GENES=$((TOTAL_GENES + N_FFN))
    TOTAL_MAGS=$((TOTAL_MAGS + 1))

    echo "Merged: $MAG   genes=$N_FFN"

done < "$MAG_LIST"

# ------------------------------------------------------------
# final QC
# ------------------------------------------------------------

if [[ "$TOTAL_MAGS" -ne 374 ]]; then
    echo "ERROR: expected 374 MAGs, got $TOTAL_MAGS"
    exit 1
fi

MERGED_FFN=$(grep -c '^>' "$FFN_TMP")
MERGED_FAA=$(grep -c '^>' "$FAA_TMP")
MAP_ROWS=$(awk 'END{print NR-1}' "$MAP_TMP")
SUMMARY_ROWS=$(awk 'END{print NR-1}' "$SUMMARY_TMP")

echo
echo "===== QC ====="
echo "MAGs                 : $TOTAL_MAGS"
echo "Total predicted genes: $TOTAL_GENES"
echo "Merged FFN genes     : $MERGED_FFN"
echo "Merged FAA proteins  : $MERGED_FAA"
echo "Gene-to-MAG rows     : $MAP_ROWS"
echo "Summary MAG rows     : $SUMMARY_ROWS"

if [[ "$MERGED_FFN" -ne "$TOTAL_GENES" ]]; then
    echo "ERROR: merged FFN count mismatch"
    exit 1
fi

if [[ "$MERGED_FAA" -ne "$TOTAL_GENES" ]]; then
    echo "ERROR: merged FAA count mismatch"
    exit 1
fi

if [[ "$MAP_ROWS" -ne "$TOTAL_GENES" ]]; then
    echo "ERROR: gene-to-MAG count mismatch"
    exit 1
fi

if [[ "$SUMMARY_ROWS" -ne 374 ]]; then
    echo "ERROR: MAG summary count mismatch"
    exit 1
fi

# ------------------------------------------------------------
# finalize atomically
# ------------------------------------------------------------

mv "$FFN_TMP" "$FFN"
mv "$FAA_TMP" "$FAA"
mv "$MAP_TMP" "$MAP"
mv "$SUMMARY_TMP" "$SUMMARY"

touch "$DONE"

echo
echo "===== final files ====="

ls -lh \
    "$FFN" \
    "$FAA" \
    "$MAP" \
    "$SUMMARY"

echo
echo "Finish : $(date)"
echo "============================================================"
