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

## Immutable T/W lineage

The frozen scientific `T` matrix is generated in Monte Carlo; `W` is the candidate weight matrix learned by Discovery. T must remain unchanged during training and validation, and W must remain unchanged after Discovery. The existing 192-model confirmatory manifest already includes one SHA-256 per frozen W file; the downstream scorer now verifies those SHA-256 values and exports `w_candidate_trace.csv`.

Each downstream source-target-seed scoring shard exports `t_scenario_trace.csv`, containing a stable matrix ID and scenario ID plus SHA-256 digests of the numeric T matrix and target. Individual components and cells are identified without a giant per-cell CSV by the deterministic scheme `T-<family>-s<seed>-n<n>-r<reps>-sc<scenario>-r<replication>-c<component_index>`. Component index follows the canonical ordered 26-estimator registry. The IDs are *coordinates*, while the cryptographic scenario hash authenticates the associated data contents. The scorer rejects a preexisting trace that differs from a recomputed trace.

Current limitation: the hashes are checked/generated in the downstream scoring stage; they are not retroactively embedded inside ongoing Monte Carlo artifacts. Unchanged upstream output is intentional. A full end-to-end smoke test of this new trace layer is required before merging.
