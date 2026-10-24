# T2 downstream bounded-memory evaluation

Downstream-only optimization, retaining original MSE and type-8 q95 definitions:

- `R/00_shared/batching.R` exposes `t2_batch_indices`, `t2_score_models_batched`, `t2_score_scenarios_batched`.
- Held-out and Stress evaluate scenarios in configurable batches, and candidates in batches.
- Real-world scoring groups datasets in configurable batches; the existing prepared bundle and integrated bootstrap audit remain in memory and require a future streaming refactor if profiling identifies them as bottlenecks.
- Discovery fitness already used 32-weight vectorized batches; its size is now configurable.

Environment variables: `T2_MODEL_BATCH_SIZE=32`, `T2_SCENARIO_BATCH_SIZE=8`, `T2_DATASET_BATCH_SIZE=1`, `T2_FITNESS_BATCH_SIZE=32`. All must be positive integers. The choice of batch size should not change estimators or experimental seeds.

Limitations: A complete canonical input RDS is still loaded per family/seed and confirmatory portfolio scoring and some inference paths retain materialized intermediate tables. Batch execution bounds prediction intermediates but does not yet guarantee fully streaming memory usage across every downstream component. Full empirical performance and equivalence testing is pending; no speedup is claimed without benchmarking. This update is separate from the currently running Monte Carlo computation.

## Incremental phase

- Confirmatory portfolio scoring now processes candidate weights in bounded matrix batches and writes each batch to a temporary CSV. It atomically publishes `scores.csv` only after complete success; the existing scoring output columns and statistical definitions are preserved. This prevents the old per-candidate `rows` accumulation.
- Real-world bootstrap preparation now generates observations for one replicate at a time and immediately computes the 26 estimators, avoiding the former n-by-R raw sample matrix and sample list. The RNG call order is preserved by a sequential loop, subject to verification on the pinned runtime.
- Existing Held-out and Stress batching remains enabled.

Still outstanding: the full canonical T payload is loaded into memory per source shard; confirmatory inference and global BH-FDR report assembly materialize complete tables; the real-world integrated audit also retains all condition results. Changing these safely requires streaming statistical accumulators and equivalence tests. There is no established performance or numerical-equivalence benchmark yet, and an R runtime is not available in the current inspection environment.

## Global inference and report pass

- Portfolio inference now reads one seed CSV at a time, aggregates with the original exact model/scenario/seed grouping and frees each source table before advancing.
- Portfolio report now uses two passes over source-target taxonomies. Pass one keeps compact MSE and q95 p-value vectors across all 36 source-target pairs, ensuring **unchanged global BH-FDR families**. Pass two reads one taxonomy at a time, applies its corresponding globally adjusted q-values, and appends its classified rows into a temporary CSV. Completed global files are published by atomic rename.
- This reduces full-table simultaneous residency. Global BH adjustment still needs all p-values for its family; an external-memory sorting implementation would be needed to bound even those vectors. Regional winner summary continues to load relatively small winner tables.
- Runtime and output equivalence checks have NOT been run; the current environment has no Rscript executable. No full-stage validation or speed benchmark is claimed.
