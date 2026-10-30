# Selective immutable canonical T storage

`R/00_shared/scenario_store.R` adds an **optional** sidecar directory `<canonical>.scenarios/` with per-scenario RDS and `scientific_manifest.csv`. The manifest has scenario IDs, individual SHA-256 hashes, family/seed provenance, dimensions and relative filenames. Scientific W candidate dependencies still use the separately verified frozen W manifest.

To convert an archived full block without changing the source RDS: `Rscript scripts/build_scenario_store.R FAMILY SEED N REPS`. On an existing manifest the tool verifies it. A partial conversion without the manifest is rejected to prevent silently mixing old and new contents. Keep a copy of the original canonical RDS.

Portfolio scoring automatically chooses the sidecar only when its manifest is present; it verifies selected scenario hashes before scoring and checks IDs and numeric matrix shape as scenarios are opened. It writes the exact consumed dependency rows to `provenance/scientific_dependencies.csv` and reads **one T scenario at a time**. Where the store is absent, the existing complete canonical RDS fallback remains in place. The split sidecar is a cache/derived immutable representation, not a replacement for canonical scientific provenance.

Important integration limitation: the current Actions artifact transfer still downloads the full named canonical artifact. Selective network retrieval requires uploading the sidecars as smaller individually addressable scientific artifacts or using a storage provider with per-file downloads. The new reader removes the full RDS *RAM load* only when sidecar files are actually delivered to the job. It cannot manufacture selective downloads from the monolithic RDS on demand. Benchmarks and R execution tests remain outstanding.
