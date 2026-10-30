# T2 Data Contracts — v1

The downstream modules share three validated contracts, implemented in `R/00_shared/data_contracts.R` and loaded by the existing `pipeline.R` compatibility entrypoint.

- `t2_validate_T`: requires a nonempty list of scenarios, unique positive IDs, finite numeric R x 26 estimator matrices, consistent canonical component names (when present) and finite numeric target. Optional family, seed, repetitions and scenario count checks.
- `t2_validate_W`: requires unique candidate IDs, finite nonnegative 26-component simplex weights (sum within 1e-8 of 1), or named reference components.
- `t2_validate_scores`: requires nonempty data frame, model/mse/q95 fields, finite nonnegative numerical metrics, and optional expected model coverage.

The validators are read-only; no existing Monte Carlo file or weight vector is rewritten. Current consumers include Discovery input, Held-out and Stress input and outputs, and final aggregation. The existing confirmatory T/W frozen hashing remains an additional provenance check. Legacy RDS and CSV payloads retain their current layout; the optional `t2_contract_stamp` helper returns a v1 contract identifier for future manifests.

Pending: exercise validators against archived real scientific artifacts, extend the contracts to specialized confirmatory score schemas and enforce output coverage as appropriate for each experiment. The contract module is a code-level safeguard and does not establish that a complete downstream run has passed.
