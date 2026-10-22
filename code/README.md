# T2 procedural code map

This directory is the human-facing, ordered entry point for the T2 experiment.
It does not duplicate the authoritative implementation in `R/`, `scripts/`,
`config/`, and `.github/workflows/`: duplicating those files would create two
versions of the experiment.  Each numbered module identifies the exact
authoritative scripts, inputs, outputs and execution order.

Run modules in numeric order.  A module may consume a retained immutable
artifact rather than regenerate it; this is recorded in `PIPELINE_MANIFEST.csv`.
Never use a later-stage result to change an earlier-stage input.

1. `01_montecarlo_T`: canonical component matrices T for discovery.
2. `02_discovery_Wstar`: four search engines create and freeze W*.
3. `03_independent_matrices`: independent T matrices, split by seed role.
4. `04_validation_and_confirmation`: held-out, stress, portfolio and inference.
5. `05_realworld_external`: external parent-dataset audit of frozen W*.
6. `06_final_synthesis`: joins predeclared outputs without retraining.

`00_environment` is required before any computational module.
