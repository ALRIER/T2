# Canonical Monte Carlo contract

T2 now generates Monte Carlo blocks once and reuses them. A block is identified by
`mode`, family, seed index, sample size, and replication count, and is stored below
`artifacts/mc_canonical/` (or `T2_CANONICAL_MC_ROOT`). The four discovery engines
receive the same canonical training block for a given family and seed.

The seed contract is fixed:

- indices `0:7`: eight training seeds;
- index `8`: reserved held-out seed;
- no discovery engine may consume seed `8`.

The held-out stage loads the reserved seed through the same canonical cache, with
independent sample-size blocks. It does not regenerate scenario data inside each
engine shard. Stress evaluation uses the reserved seed but remains a separate
evaluation product and cannot feed discovery.

Each block is checkpointed by contamination-grid scenario under a `.parts/`
directory, with a progress record containing the deterministic seed scheme. A restart reuses the
completed scenario files and resumes from the next confirmed scenario. The final
RDS is written atomically only after all grid scenarios have been verified.

Scenario seeds are deterministic and independent of execution order. On Unix
runners, `T2_MC_WORKERS` can process several scenarios concurrently; the production
workflow uses two workers per canonical job and checkpoints each completed scenario.

Legacy NEST26 outputs from Zenodo are retained as historical validation material,
not as a substitute for the new T2 training or held-out matrices. The source record
is <https://doi.org/10.5281/zenodo.21046199>.
