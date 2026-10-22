# 02 — Discovery and W*

This module consumes discovery T matrices and evaluates GA, NSGA-II, DE and
Dirichlet under the same component registry and budget contract.  Discovery
produces candidate weights only.  Once exported in
`config/confirmatory_frozen_models.csv`, W* must not be retrained or amended
by held-out, stress, portfolio or external outcomes.

Authoritative stage entry point:

```bash
Rscript scripts/run_stage.R discovery SHARD full FAMILY SEED ENGINE
```
