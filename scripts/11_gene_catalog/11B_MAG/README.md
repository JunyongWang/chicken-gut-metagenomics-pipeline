# 11B MAG-specific reference scripts

These scripts run single-genome Prodigal for 374 dRep representatives and merge the resulting FFN/FAA catalogs with a gene-to-MAG mapping. They do not perform gene-length filtering, MMseqs2 clustering, or Salmon quantification.

Set `WORK_ROOT`, `MAG_DIR`, `MAG_LIST`, and `CONDA_SH` for prediction. The archive does not supply an authoritative ordered 374-MAG manifest, so none is invented here.
