# Production readiness audit

Status: NOT READY FOR FULL EXPERIMENT.

- Stage order now enforces dataset manifest verification and Monte Carlo validation before simulation and Discovery.
- The four original legacy validation layers are preserved as source but are not ported into the current function environment. The current four quick numerical checks are NOT equivalent to the historical scientific suite. Full mode rejects them.
- The historical Monte Carlo empirical-anchoring layer is distinct from the final real-world external battery. Its five-anchor adapter and shape-range execution are integrated, but acquisition, licensing, and final hashing are still pending.
- Current public datasets manifest contains only a checked-in test fixture. Full mode rejects it.
- Full realworld and stress stages currently stop deliberately.
- Checkpoints are local RDS artifacts; cross-workflow durable restoration and hash/version binding are not yet proven.
- Each family/optimizer/seed shard now writes raw inputs, checkpoints, RDS/CSV results and trace manifests under `artifacts/<shard>/<stage>/`; GitHub Actions uploads those directories as run artifacts.
- The Actions matrix is bounded to 8 concurrent jobs and 360 minutes per job, matching the six-hour GitHub-hosted job ceiling; stage artifacts are uploaded incrementally for recovery.
- Optimizer equivalence and q95 inferential validity require dedicated executed tests.
- Public Git history and owner attribution cannot be erased by changing the current tree; do not confuse sanitizing source text with eliminating historical links.
- Preserve reproducible configurations, scientific variable definitions and model contracts in the execution code. Obfuscation that makes audit impossible is not scientific anonymization.

Release gate: the above must be resolved and the full integrated smoke, resumption and pilot must PASS in GitHub Actions before production.
