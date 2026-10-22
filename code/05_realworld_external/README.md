# 05 — External real-world confirmation

The external battery applies frozen W* to the processed historical public-data
structure.  Dataset profile and benchmark are fixed before scoring.  Repeated
variables or resamples from one source are aggregated to `parent_dataset_id`
before inference, yielding 37 independent source parents from 48 processed
records.  Out-of-profile rows remain audit records.

Entry points:

```bash
Rscript scripts/run_legacy_realworld_confirmatory.R score full
Rscript scripts/merge_legacy_realworld_shards.R
Rscript scripts/run_legacy_realworld_confirmatory.R inference full
```

Workflow: `.github/workflows/confirmatory-legacy-realworld.yml`.
