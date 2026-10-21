#!/usr/bin/env Rscript

source('R/00_shared/load_all.R')
t2_load('.')
source('R/00_shared/pipeline.R')
t2_check_runtime('.', strict = TRUE)

pf <- t2_confirmatory_preflight('full')
stopifnot(identical(pf$status, 'PASS'), pf$models == 192L,
          identical(pf$confirmatory_seeds, 9:16),
          identical(pf$sample_sizes, c(200L, 1000L, 3000L)),
          pf$replications == 500L)

manifest <- t2_confirmatory_model_manifest()
stopifnot(nrow(manifest) == 192L,
          length(unique(manifest$family)) == 6L,
          length(unique(manifest$engine)) == 4L,
          all(manifest$training_seed %in% 0:7))

external <- t2_confirmatory_realworld_manifest()
stopifnot(nrow(external) == 20L,
          all(external$family_hint == 'all'),
          length(unique(external$independence_group)) == 20L,
          all(file.exists(external$path)),
          all(file.exists(external$raw_path)))

old <- read.csv('config/public_datasets.csv', stringsAsFactors = FALSE,
                check.names = FALSE)
stopifnot(!any(external$dataset_id %in% old$dataset_id))

# The smoke artifacts are contract checks only. They must never be interpreted
# as confirmatory evidence because they contain one confirmatory seed and 20
# replicates rather than the prespecified full design.
smoke_root <- file.path(t2_confirmatory_root(), 'realworld')
if (file.exists(file.path(smoke_root, 'score.status'))) {
  stopifnot(file.exists(file.path(smoke_root, 'scores.csv')),
            file.exists(file.path(smoke_root, 'manifest_verified.csv')))
}

cat('CONFIRMATORY CONTRACT PASS\n')
