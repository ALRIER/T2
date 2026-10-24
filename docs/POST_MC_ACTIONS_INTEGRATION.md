# T2 post-Monte-Carlo Actions integration

## Source and recovery

The downstream workflow accepts `validation_run_id` as a manual dispatch input and downloads the existing immutable `validation-<family>-seed-<seed>` artifacts using GitHub Actions permissions. Exactly one `n1000_r500.rds` must be found per selected partition; further R-level validation checks 361 unique scenario identifiers, a 500 x 26 numeric finite estimator matrix per scenario, and finite targets. An invalid or absent partition fails the consumer without changing its source. The downstream recovery process uses source artifacts without altering them. Zenodo is not required for this consumer path.

## Before enabling

1. Inventory and verify the upstream run ID and all artifact names, storage expiry and data dimensions (source might not use these names).
2. Verify a complete independent local snapshot and SHA256 manifests, and ensure restoration is reversible.
3. Run a separate smoke validation of a copied partition without touching active runs.
4. After verification, enable the downstream workflow with the correct source run ID.

This PR is an initial consumer-side safety change, not evidence that the entire T2 pipeline is ready to run.
