# 01 — Canonical Monte Carlo matrix T

Each T matrix has one row per replicate and 26 fixed classical/robust component
estimates.  It is generated once per family/seed/input contract, checksummed,
then reused by downstream search and confirmation.

Discovery uses seeds 00–07.  Seed 08 is strictly reserved for the original
held-out/stress stream.  Do not use a confirmation seed for discovery.

Entry point: `scripts/generate_canonical_mc.R MODE FAMILY SEED_INDEX`.
For published canonical inputs use the verified Zenodo retrieval in
`.github/workflows/smoke.yml`; do not silently regenerate an archived matrix.
