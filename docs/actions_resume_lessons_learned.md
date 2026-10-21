# Actions resume lessons

## Observed failure

The global preparation jobs completed successfully: preflight, plan,
shared-validation, backup-preflight, and all six precomputed Monte Carlo
packages. The failure appeared later in individual discovery shards.

The first failed run reported a budget-audit contract mismatch because each
shard intentionally contains one discovery engine while the audit expected
all four engines in the same object. That contract is now represented by a
four-engine budget registry, so the held-out audit can run inside a single
engine shard without weakening the parity check.

The next resumed run exposed a separate recovery issue. Some Dirichlet shards
restored optimizer checkpoints created by the previous commit. The checkpoint
engine and configuration matched, but the exact commit comparison rejected the
checkpoint. Other shards completed because they did not encounter that legacy
checkpoint path before cancellation. This explains why isolated shards, not
complete families, had different outcomes.

## Recovery rules

- Monte Carlo and shared validation are restored from the previous run when a
  `resume_run_id` is supplied; they are not recomputed.
- An optimizer checkpoint must always match its engine, configuration, and
  checkpoint schema.
- During an explicit resume, a legacy checkpoint without a schema may cross a
  commit boundary only when the workflow sets
  `T2_ALLOW_LEGACY_CHECKPOINT_COMMIT=1`.
- New checkpoints carry `checkpoint_schema=optimizer-v1`; a future schema
  remains incompatible and is rejected instead of silently mixing states.
- The full matrix remains parallel: one engine, family, and seed per shard,
  with the global concurrency limit enforced by Actions.

## Evidence

The local contract checks passed for the four-engine budget registry, legacy
checkpoint recovery, checkpoint structure, and resume behavior. The Actions
run with the failure was cancelled before relaunching after this correction.
