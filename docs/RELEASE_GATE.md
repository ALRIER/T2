# Production readiness audit

Status: NOT READY FOR FULL EXPERIMENT.

- Stage order now enforces dataset manifest verification and Monte Carlo validation before simulation and Discovery.
- The four original legacy validation layers are preserved as source but are not ported into the current function environment. The current four quick numerical checks are NOT equivalent to the historical scientific suite. Full mode rejects them.
- Current public datasets manifest contains only a checked-in test fixture. Full mode rejects it.
- Full realworld and stress stages currently stop deliberately.
- Checkpoints are local RDS artifacts; cross-workflow durable restoration and hash/version binding are not yet proven.
- Optimizer equivalence and q95 inferential validity require dedicated executed tests.
- Public Git history and owner attribution cannot be erased by changing the current tree; do not confuse sanitizing source text with eliminating historical links.
- Preserve reproducible configurations, scientific variable definitions and model contracts in the execution code. Obfuscation that makes audit impossible is not scientific anonymization.

Release gate: the above must be resolved and the full integrated smoke, resumption and pilot must PASS in GitHub Actions before production.
