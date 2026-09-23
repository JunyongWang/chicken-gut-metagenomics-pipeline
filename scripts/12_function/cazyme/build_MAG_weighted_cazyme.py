#!/usr/bin/env python3
import csv, math, os

WORK_ROOT=os.environ.get("WORK_ROOT")
STAGE_DIR=os.environ.get("STAGE_DIR", os.path.join(WORK_ROOT, "12_function") if WORK_ROOT else ".")
TPM=os.environ.get("MAG_TPM", os.path.join(WORK_ROOT, "10_coverm/matrices/MAG_tpm.tsv") if WORK_ROOT else "../10_coverm/matrices/MAG_tpm.tsv")
CNT=os.environ.get("MAG_CAZYME_MATRIX", os.path.join(STAGE_DIR, "dbcan/11B/matrix/MAG_cazyme_gene_count_matrix.tsv"))
OUT=os.environ.get("MAG_WEIGHTED_CAZYME_OUT", os.path.join(STAGE_DIR, "dbcan/11B/weighted"))

EXPECTED_MAGS=374
EXPECTED_FAMS=266
EXPECTED_SAMPLES=[f"M{i}" for i in range(1,62) if i!=23]

def read_tpm(path):
    data={}
    with open(path,newline="") as f:
        r=csv.reader(f,delimiter="\t")
        h=next(r)
        if h[0]!="Genome":
            raise RuntimeError(f"bad TPM header: {h[0]}")
        samples=h[1:]
        if samples!=EXPECTED_SAMPLES:
            raise RuntimeError("unexpected sample order in MAG_tpm.tsv")

        for row in r:
            mag=row[0]

            if mag in data:
                raise RuntimeError(f"duplicate MAG in TPM: {mag}")

            vals=[float(x) for x in row[1:]]

            if len(vals)!=len(samples) or any(x<0 for x in vals):
                raise RuntimeError(f"bad TPM row: {mag}")

            data[mag]=vals

    return samples,data


def read_counts(path):
    data={}
    with open(path,newline="") as f:
        r=csv.reader(f,delimiter="\t")
        h=next(r)

        if h[0]!="MAG":
            raise RuntimeError(f"bad count header: {h[0]}")

        fams=h[1:]

        for row in r:
            mag=row[0]

            if mag in data:
                raise RuntimeError(f"duplicate MAG in counts: {mag}")

            vals=[int(x) for x in row[1:]]

            if len(vals)!=len(fams) or any(x<0 for x in vals):
                raise RuntimeError(f"bad count row: {mag}")

            data[mag]=vals

    return fams,data


samples,tpm=read_tpm(TPM)
fams,cnt=read_counts(CNT)

if len(tpm)!=EXPECTED_MAGS or len(cnt)!=EXPECTED_MAGS:
    raise RuntimeError("MAG count mismatch")

if len(fams)!=EXPECTED_FAMS:
    raise RuntimeError("family count mismatch")

if set(tpm)!=set(cnt):
    raise RuntimeError("MAG sets differ")


tpm_sum=[0.0]*len(samples)

weighted=[
    [0.0]*len(samples)
    for _ in fams
]

expected=[0.0]*len(samples)


for mag in cnt:
    tv=tpm[mag]
    cv=cnt[mag]

    links=sum(cv)

    for j,x in enumerate(tv):
        tpm_sum[j]+=x
        expected[j]+=x*links

    for i,n in enumerate(cv):
        if n:
            out=weighted[i]

            for j,x in enumerate(tv):
                out[j]+=n*x


observed=[
    sum(weighted[i][j] for i in range(len(fams)))
    for j in range(len(samples))
]


for s,obs,exp in zip(samples,observed,expected):
    if not math.isclose(
        obs,
        exp,
        rel_tol=1e-12,
        abs_tol=1e-5
    ):
        raise RuntimeError(
            f"weighted conservation failed: {s}"
        )


os.makedirs(OUT,exist_ok=True)


with open(
    os.path.join(
        OUT,
        "MAG_weighted_cazyme_TPM.tsv"
    ),
    "w",
    newline=""
) as f:
    w=csv.writer(
        f,
        delimiter="\t",
        lineterminator="\n"
    )

    w.writerow([
        "Family",
        *samples
    ])

    for fam,row in zip(fams,weighted):
        w.writerow([
            fam,
            *[f"{x:.6f}" for x in row]
        ])


with open(
    os.path.join(
        OUT,
        "MAG_weighted_cazyme_QC.tsv"
    ),
    "w",
    newline=""
) as f:
    w=csv.writer(
        f,
        delimiter="\t",
        lineterminator="\n"
    )

    w.writerow([
        "Sample",
        "MAG_TPM_Sum",
        "Weighted_Total",
        "Independent_Expected_Total",
        "Absolute_Difference"
    ])

    for s,ts,obs,exp in zip(
        samples,
        tpm_sum,
        observed,
        expected
    ):
        w.writerow([
            s,
            f"{ts:.6f}",
            f"{obs:.6f}",
            f"{exp:.6f}",
            f"{abs(obs-exp):.12f}"
        ])


with open(
    os.path.join(
        OUT,
        "MAG_weighted_cazyme_summary.tsv"
    ),
    "w"
) as f:
    f.write("metric\tvalue\n")
    f.write(f"MAGs\t{len(tpm)}\n")
    f.write(f"families\t{len(fams)}\n")
    f.write(f"samples\t{len(samples)}\n")
    f.write("weight_metric\tCoverM_genome_TPM\n")
    f.write(
        "formula\t"
        "sum_MAG(CAZyme_family_gene_count*MAG_TPM)\n"
    )
    f.write(
        f"min_MAG_TPM_sum\t{min(tpm_sum):.6f}\n"
    )
    f.write(
        f"max_MAG_TPM_sum\t{max(tpm_sum):.6f}\n"
    )


print("12B-5 complete")
print(
    "MAGs",
    len(tpm),
    "families",
    len(fams),
    "samples",
    len(samples)
)
print(
    "MAG TPM sum range",
    f"{min(tpm_sum):.6f}",
    f"{max(tpm_sum):.6f}"
)
