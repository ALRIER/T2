# T2 confirmatory layer

This layer is independent of the completed exploratory full run. It never
re-trains a model and never chooses a winner after seeing confirmatory data.

The frozen candidates are the 192 discovery vectors (six families, four
engines, eight training seeds). The confirmatory Monte Carlo streams use seeds
9--16, 500 replicates per condition, and sample sizes 200, 1000, and 3000.
The primary reference is the sample mean. The primary hypothesis is defined at
the family-by-engine level and requires improvement in both MSE and q95.

For each condition the runner stores paired squared errors for every frozen
candidate against the fixed reference. The primary analysis averages the eight
frozen training vectors within each fresh confirmation seed, then applies a
paired block bootstrap over the eight confirmation seeds. BH-FDR is applied
separately to the 24 MSE and 24 q95 primary hypotheses. A primary result is
confirmed only when both metrics have positive gain, an interval entirely on
the improving side, and q <= 0.05.

The current real-world battery is exploratory and is not reused as the
confirmatory battery. The confirmatory panel contains 20 independent parent
objects materialized from the version-pinned R `datasets` package. Each parent
is scored against all six distribution families and all four learned engines;
`family_hint=all` is a scope declaration, not a data-driven assignment. The
parent dataset, not a repeated subsample, is the external inferential block.
`config/confirmatory_public_datasets.csv` fixes paths, licenses,
transformations, source objects, and SHA-256 digests before dispatch.

The raw and processed CSV exports are retained in
`data/confirmatory/realworld/{raw,processed}`. The adapter consumes only the
processed file and applies no hidden transformation (`transform=raw`).

Large raw-error files are checkpointed and uploaded as chunked artifacts. Git
stores the protocol, manifests, code, summaries, and checksums; it does not
store a large generated error matrix.

The frozen input package is also published as a neutral recovery copy at
`10.5281/zenodo.23547992`. Actions does not depend on this external copy for
the normal run: the workflow takes its code, frozen models, and external input
files from the repository. The Zenodo package is used for recovery and
independent archival verification.
