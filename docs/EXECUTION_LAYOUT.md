# Execution and artifact layout

Every independent run is a shard identified by family, optimizer engine and seed. The default output root is `artifacts/`; CI can override it with `T2_OUTPUT_ROOT`.

`T2_MAX_FILE_MB` controls the maximum artifact part size and defaults to `25`. Oversized CSVs are split into `.part-####.csv` files; oversized RDS payloads are split into `.part-####` files with a small RDS index and SHA-256 checksums. A stage cannot receive a `COMPLETE` marker if any artifact part is missing, oversized or corrupt.

```text
artifacts/<shard>/<stage>/
  raw/          immutable inputs and generated matrices
  checkpoints/  completion markers for resumable stage execution
  results/      RDS products and tabular summaries
  trace/        events.csv and run_manifest.csv
```

Use `Rscript scripts/run_stage.R STAGE SHARD MODE FAMILY SEED_INDEX ENGINE` for one stage or `Rscript scripts/run_shard.R MODE FAMILY SEED_INDEX ENGINE` for the complete dependency chain. A shard is independent, so optimizer engines, families and seeds can run concurrently in GitHub Actions without sharing mutable state.

For a new attempt, dispatch the workflow with `resume_run_id` set to the previous Verification run ID. The workflow downloads the last uploaded shard artifact, skips every stage with a valid `COMPLETE` checkpoint, and reruns only the incomplete stage and its dependents. Uploads are replaced after each stage, so a job timeout preserves the last stable boundary. This is bounded recovery, not an unlimited job: GitHub-hosted jobs remain subject to the platform's six-hour maximum (360 minutes).

The repository stores the output contract and CI uploads each shard's generated artifacts to the corresponding Actions run. Production runs should retain or explicitly commit the resulting `artifacts/<shard>/` tree after review; large raw matrices should remain Actions artifacts rather than being copied into Git history.
