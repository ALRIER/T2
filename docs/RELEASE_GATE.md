# Production readiness audit

Status: NOT READY FOR FULL EXPERIMENT.

- Stage order now enforces dataset manifest verification and Monte Carlo validation before simulation and Discovery.
- The historical Monte Carlo audit layers L1 (moment fidelity), L2 (contamination fidelity), and L3 (statistical sanity) are now integrated and pass the local smoke contract. L4 empirical anchoring remains a separate five-input full-mode gate; it is not the final real-world battery.
- The historical Monte Carlo empirical-anchoring adapter and shape-range execution are integrated. Four anchors are acquired, while the fifth SPY input requires an approved private/non-redistributable path and is intentionally not checked into the repository.
- Current public datasets manifest contains only a checked-in test fixture. Full mode rejects it.
- Full realworld and stress stages currently stop deliberately.
- Local stage-resume is contract-tested, and cross-workflow GitHub artifact restoration was verified by manual run `39447280249` restoring run `39446799142`; all eight completed stages were detected and skipped.
- Each family/optimizer/seed shard now writes raw inputs, checkpoints, RDS/CSV results and trace manifests under `artifacts/<shard>/<stage>/`; GitHub Actions uploads those directories as run artifacts.
- The Actions matrix is bounded to 8 concurrent jobs and 360 minutes per job, matching the six-hour GitHub-hosted job ceiling; stage artifacts are uploaded incrementally for recovery.
- Discovery now enumerates the four agreed competitors independently: GA original, NSGA-II, Differential Evolution, and Dirichlet. The first is scalar single-objective GA selection; NSGA-II remains a separate multiobjective comparator.
- Optimizer equivalence and q95 inferential validity require dedicated executed tests.
- Public Git history and owner attribution cannot be erased by changing the current tree; do not confuse sanitizing source text with eliminating historical links.
- Preserve reproducible configurations, scientific variable definitions and model contracts in the execution code. Obfuscation that makes audit impossible is not scientific anonymization.

Release gate: the above must be resolved and the full integrated smoke, resumption and pilot must PASS in GitHub Actions before production.
