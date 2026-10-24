# T2 downstream scientific-input contract

## Scientific data versus recovery artifacts

The downstream stages import only the scientific inputs needed by their computation. The current frozen portfolio implementation requires the canonical estimator matrix T stored in `n1000_r500.rds`. A CSV or packaged archive may be accepted by a future adapter only if it preserves every required scenario, estimator column, target, seed, and provenance field. CSV summaries alone cannot reconstruct the canonical raw T matrices.

Checkpoints, progress RDS, runner logs, temporary parts, and transfer metadata belong to the recovery layer. They are not part of the downstream study inputs and are not copied into the consumer's canonical input directory. Scientific input copies are immutable.

## GitHub Actions transfer detail

The consumer identifies one source run using the required `validation_run_id` parameter, then downloads the named family/seed artifact, selects exactly one canonical `n1000_r500.rds`, copies it into the expected scientific directory and discards its staging directory. The R-level gate checks 361 scenario IDs, numeric 500-by-26 T matrices and finite targets.

**Important:** `actions/download-artifact` transfers the entire named artifact first. Selecting one RDS reduces retained and processed data, but it does not reduce network bytes inside that artifact. To actually reduce transfer traffic, future upstream publication must expose separately named scientific-only artifacts (or an immutable RAW bundle per family/seed); there is no need to change historical jobs. The source names and artifact contents must be verified before activating this flow.

## Verification

1. Inventory current source artifact names and their provenance.
2. Confirm the downstream RDS adapter works with the actual archived structure and checksums.
3. Preserve the independent local scientific backup and test restoring it.
4. Run a small downstream-only integration test, then enable the complete consumer after verifying required scientific partitions.
