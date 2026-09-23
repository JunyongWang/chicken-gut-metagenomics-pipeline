# dbCAN reference scripts

These scripts reproduce the verified dbCAN 5.2.9 protein-annotation workflow.

The formal method invocation is exactly `--methods diamond,hmm,dbCANsub` as one argument. Recommended CAZyme genes are defined by dbCAN V5 `overview.tsv` with `#ofTools >= 2`.

The MAG branch uses seven chunks totaling 688,771 proteins. The NR branch reuses the 132 eggNOG NR chunks and has the archived array `1-132%20`. Historical outputs from an incorrect method invocation are not part of this reference workflow.
