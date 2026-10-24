# T2 downstream bounded-memory evaluation

Downstream-only optimization, retaining original MSE and type-8 q95 definitions:

- `R/00_shared/batching.R` exposes `t2_batch_indices`, `t2_score_models_batched`, `t2_score_scenarios_batched`.
- Held-out and Stress evaluate scenarios in configurable batches, and candidates in batches.
- Real-world scoring groups datasets in configurable batches; the existing prepared bundle and integrated bootstrap audit remain in memory and require a future streaming refactor if profiling identifies them as bottlenecks.
- Discovery fitness already used 32-weight vectorized batches; its size is now configurable.

Environment variables: `T2_MODEL_BATCH_SIZE=32`, `T2_SCENARIO_BATCH_SIZE=8`, `T2_DATASET_BATCH_SIZE=1`, `T2_FITNESS_BATCH_SIZE=32`. All must be positive integers. The choice of batch size should not change estimators or experimental seeds.

Limitations: A complete canonical input RDS is still loaded per family/seed and confirmatory portfolio scoring and some inference paths retain materialized intermediate tables. Batch execution bounds prediction intermediates but does not yet guarantee fully streaming memory usage across every downstream component. Full empirical performance and equivalence testing is pending; no speedup is claimed without benchmarking. This update is separate from the currently running Monte Carlo computation.
