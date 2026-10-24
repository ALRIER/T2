# T2 downstream module boundaries

The public compatibility entrypoint remains `source('R/00_shared/pipeline.R')` after `t2_load('.')`. It loads downstream runners without renaming the public `t2_run_*` functions or changing the scientific Monte Carlo generation function bodies.

| Module | Responsibility |
|---|---|
| `R/00_shared/pipeline.R` | Existing Monte Carlo generation and stage orchestration |
| `R/00_shared/mc_loader.R` | Resolve canonical Monte Carlo reference for downstream Discovery |
| `R/00_shared/artifact_registry.R` | Resolve prior stage artifacts and validate stage prerequisites |
| `R/00_shared/frozen_registry.R` | Build frozen candidate models from optimizer outputs |
| `R/02_discovery/discovery_runner.R` | Run independent optimizer dispatch |
| `R/03_heldout/validation_runner.R` | Dataset certification, Monte Carlo verification, held-out and stress runners |
| `R/04_real_datasets/realworld_runner.R` | Real-world runner adapter |
| `R/05_audits/inference_runner.R` | Common inference and aggregation |
| `R/06_confirmatory/immutable_provenance.R` | Immutable post-Monte-Carlo T/W lineage, used by confirmatory scoring |

The functions are moved without changing their names or input/output contracts. Downstream references resolve at execution time in the same R environment, preserving compatibility with existing entrypoints. They are *separately maintainable*, not yet fully namespace-isolated: full environment isolation would require introducing explicit dependencies and integration testing. No claims of a successful runtime smoke test are made by this refactor.
