# eggNOG reference scripts

These scripts reproduce the verified Stage 12A workflow with eggNOG-mapper 2.1.15 and eggNOG 5.0.2 data.

The MAG branch annotates seven pre-staged chunks totaling 688,771 proteins. The exact historical MAG chunk-staging command was not captured, so `eggnog_MAG_array.sh` accepts `EGGNOG_MAG_CHUNKS_DIR` and `EGGNOG_MAG_CHUNKS_FILE` instead of inventing that step.

The NR branch splits 13,151,701 proteins into 132 chunks. Twelve chunks were completed by the original full-emapper route; the remaining 120 used DIAMOND-only Stage 1 followed by batched `no_search` Stage 2 annotation. The 40G Stage 1 retry preserves the same analytical command. Array directives absent from the archived production scripts remain unspecified.

Stage 2 expects 12 ten-chunk manifest files. Their required structure is preserved by the annotation script, but the exact historical manifest-generation command was not archived and is not reconstructed.
