#!/usr/bin/env python3
import csv, os, re
from collections import Counter, defaultdict

WORK_ROOT=os.environ.get("WORK_ROOT")
STAGE_DIR=os.environ.get("STAGE_DIR", os.path.join(WORK_ROOT, "12_function") if WORK_ROOT else ".")
MAP=os.environ.get("GENE_TO_MAG", os.path.join(WORK_ROOT, "11_gene_catalog/11B_MAG/catalog/MAG_gene_to_MAG.tsv") if WORK_ROOT else "../11B_mag_genes/catalog/MAG_gene_to_MAG.tsv")
REC=os.environ.get("MAG_DBCAN_RECOMMENDED", os.path.join(STAGE_DIR, "dbcan/11B/final/MAG_dbcan_recommended.tsv"))
OUT=os.environ.get("MAG_CAZYME_MATRIX_OUT", os.path.join(STAGE_DIR, "dbcan/11B/matrix"))

EXP=dict(
    genes=688771, mags=374, rec=22464,
    num=22464, fams=266, links=24137,
    multi=1608, slhg=4, slht=6, slho=0
)

ORDER={"GH":0,"GT":1,"PL":2,"CE":3,"AA":4,"CBM":5}
RX=re.compile(r"^(AA|CBM|CE|GH|GT|PL)([0-9]+)$")


def norm(tok):
    if tok=="SLH":
        return None
    if tok=="CBM35inCE17":
        return "CBM35"
    base=tok.split("_",1)[0]
    m=RX.fullmatch(base)
    if not m:
        raise RuntimeError(f"bad token: {tok}")
    return m.group(1)+m.group(2)


def fkey(fam):
    m=RX.fullmatch(fam)
    return (ORDER[m.group(1)], int(m.group(2)))


gene2mag={}
mags=[]
seen_mags=set()

with open(MAP,newline="") as f:
    r=csv.reader(f,delimiter="\t")
    if next(r)[:2]!=["Gene","MAG"]:
        raise RuntimeError("bad MAG mapping header")

    for row in r:
        g,m=row[0],row[1]

        if g in gene2mag:
            raise RuntimeError(
                f"duplicate mapping gene: {g}"
            )

        gene2mag[g]=m

        if m not in seen_mags:
            seen_mags.add(m)
            mags.append(m)

assert len(gene2mag)==EXP["genes"]
assert len(mags)==EXP["mags"]


fam_genes=Counter()
mag_fam=defaultdict(Counter)
mag_rec=Counter()
map_rows=[]
seen=set()

nrec=0
nnum=0
nlinks=0
nmulti=0
nslhg=0
nslht=0
nslho=0


with open(REC,newline="") as f:
    r=csv.DictReader(f,delimiter="\t")

    need={"Gene ID","#ofTools","Recommend Results"}

    if not need.issubset(r.fieldnames or []):
        raise RuntimeError("bad dbCAN header")

    for row in r:
        g=row["Gene ID"].strip()
        tools=int(row["#ofTools"])
        rr=row["Recommend Results"].strip()

        if g in seen:
            raise RuntimeError(
                f"duplicate dbCAN gene: {g}"
            )

        if g not in gene2mag:
            raise RuntimeError(
                f"missing MAG mapping: {g}"
            )

        if tools<2:
            raise RuntimeError(
                f"#ofTools<2: {g}"
            )

        seen.add(g)
        nrec+=1

        mag=gene2mag[g]
        mag_rec[mag]+=1

        fams=[]
        slh=0

        for tok in rr.split("|"):
            tok=tok.strip()

            if tok=="SLH":
                slh+=1
                continue

            fam=norm(tok)

            if fam not in fams:
                fams.append(fam)

        if slh:
            nslhg+=1
            nslht+=slh

        if fams:
            nnum+=1
        else:
            nslho+=1

        if len(fams)>1:
            nmulti+=1

        for fam in fams:
            nlinks+=1
            fam_genes[fam]+=1
            mag_fam[mag][fam]+=1

            map_rows.append(
                (
                    g, mag, fam, tools, rr,
                    "yes" if slh else "no"
                )
            )


families=sorted(fam_genes,key=fkey)

assert nrec==EXP["rec"]
assert nnum==EXP["num"]
assert len(families)==EXP["fams"]
assert nlinks==EXP["links"]
assert nmulti==EXP["multi"]
assert nslhg==EXP["slhg"]
assert nslht==EXP["slht"]
assert nslho==EXP["slho"]

matrix_total=sum(
    sum(mag_fam[m].values())
    for m in mags
)

assert matrix_total==nlinks

os.makedirs(OUT,exist_ok=True)


def write_tsv(path,header,rows):
    with open(path,"w",newline="") as f:
        w=csv.writer(
            f,
            delimiter="\t",
            lineterminator="\n"
        )
        w.writerow(header)
        w.writerows(rows)


write_tsv(
    os.path.join(
        OUT,
        "MAG_cazyme_gene_family_map.tsv"
    ),
    [
        "Gene","MAG","Family","#ofTools",
        "Recommend_Results","Contains_SLH"
    ],
    map_rows
)

write_tsv(
    os.path.join(
        OUT,
        "MAG_cazyme_gene_count_matrix.tsv"
    ),
    ["MAG",*families],
    (
        [
            m,
            *[
                mag_fam[m].get(x,0)
                for x in families
            ]
        ]
        for m in mags
    )
)

write_tsv(
    os.path.join(
        OUT,
        "MAG_cazyme_family_gene_counts.tsv"
    ),
    ["Family","Genes","MAGs_with_family"],
    (
        [
            x,
            fam_genes[x],
            sum(
                mag_fam[m].get(x,0)>0
                for m in mags
            )
        ]
        for x in families
    )
)

write_tsv(
    os.path.join(
        OUT,
        "MAG_cazyme_MAG_summary.tsv"
    ),
    [
        "MAG",
        "Recommended_CAZyme_Genes",
        "Gene_Family_Links",
        "Distinct_Families"
    ],
    (
        [
            m,
            mag_rec[m],
            sum(mag_fam[m].values()),
            len(mag_fam[m])
        ]
        for m in mags
    )
)

summary=os.path.join(
    OUT,
    "MAG_cazyme_matrix_summary.tsv"
)

with open(summary,"w") as f:
    vals=[
        ("input_MAG_genes",len(gene2mag)),
        ("MAGs",len(mags)),
        ("recommended_genes",nrec),
        ("genes_with_numbered_cazy_family",nnum),
        ("multi_parent_family_genes",nmulti),
        ("unique_parent_families",len(families)),
        ("gene_family_links",nlinks),
        ("matrix_total_counts",matrix_total),
        ("slh_containing_genes",nslhg),
        ("slh_tokens",nslht),
        ("slh_only_genes",nslho),
        ("family_rule","parent_CAZy_family"),
        ("within_gene_duplicate_family_rule","count_once"),
        (
            "multi_family_gene_rule",
            "count_once_in_each_distinct_family"
        ),
        (
            "slh_rule",
            "exclude_SLH_keep_numbered_partner_families"
        )
    ]

    f.write("metric\tvalue\n")

    for k,v in vals:
        f.write(f"{k}\t{v}\n")


print("12B-4 complete")
print(
    "MAGs",
    len(mags),
    "families",
    len(families),
    "links",
    nlinks
)
