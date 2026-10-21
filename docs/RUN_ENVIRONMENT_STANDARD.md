# T2 — GitHub Actions execution standard

## Execution environment

All production shards execute exclusively on GitHub-hosted Actions runners. No local workstation, distributed physical worker, external coordinator or temperature sensor is required.

The reproducibility requirements remain unchanged:
- R 4.3.3, with package versions specified in `config/runtime_requirements.csv`.
- Fixed RNG kind: Mersenne-Twister / Inversion / Rejection.
- Each shard is identified by distribution family, optimizer engine and seed.
- Each shard runs all stages in sequence and preserves its own artifacts, checkpoints, manifests and session information.

The `Verification` workflow in `.github/workflows/smoke.yml` performs preflight and smoke checks, then supports a manually dispatched full matrix.

## Complete experiment matrix

The committed `config/shard_plan.csv` contains 192 distinct shards:
6 families × 4 engines (GA, NSGA-II, DE and Dirichlet) × 8 seeds.

Before those shards start, the workflow produces 54 canonical Monte Carlo blocks:
6 families × 9 seeds. Seeds 0–7 feed discovery; seed 8 is reserved for held-out
and stress evaluation. Each training shard downloads only its own family/seed block
plus that family's reserved held-out block, rather than copying the entire 54-block
archive to every runner.

Every row must have `worker_id=github_actions`. The `scripts/actions_matrix.R` command checks the entire 192-shard Cartesian product, rejects missing/duplicate/external assignments, and emits the GitHub Actions matrix. The `scripts/generate_shard_plan.R` command deterministically regenerates the Actions-only plan.

The workflow uses `max-parallel: 32` and runs each shard in an isolated GitHub-hosted job. GitHub's actual concurrent job availability may be lower. Each job has a 360-minute timeout; long-running shards still need production timing validation.

## Run and recovery

Open the repository's Actions tab and select the `Verification` workflow. Run `mode=smoke` to validate the pipeline. Only after smoke, matrix and artifact-contract checks succeed should `mode=full` be launched.

Leave `resume_run_id` empty for an initial run. To recover compatible stage artifacts, supply the prior Verification run ID. Checkpoint compatibility requires the matching commit, configuration, RNG and runtime contract. A change in commit or configuration can invalidate restoration; do not assume a prior run is automatically compatible.

Artifacts are uploaded after each stage and retained for 30 days in full mode. Validate scientific outputs and aggregation before accepting results.

## Removed execution dependency

The former physical-machine worker profiles and quota allocation are no longer part of the execution plan. Legacy local-worker scripts remain as historical utilities but are not invoked by the GitHub Actions workflow or included in production shard allocation.
