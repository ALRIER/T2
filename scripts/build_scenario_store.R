#!/usr/bin/env Rscript
# Convert one archived canonical block to an independent immutable scenario store.
# Usage: Rscript scripts/build_scenario_store.R FAMILY SEED N REPS
args <- commandArgs(trailingOnly=TRUE)
if (!length(args) %in% c(4L,5L)) stop('Usage: FAMILY SEED N REPS [heldout]')
family <- args[[1L]]; seed <- as.integer(args[[2L]])
n <- as.integer(args[[3L]]); reps <- as.integer(args[[4L]])
if (anyNA(c(seed,n,reps)) || n<1L || reps<1L) stop('Invalid canonical block coordinates')
source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
source('R/00_shared/scenario_store.R')
if (!family %in% t2_families()) stop('Unsupported family')
path <- t2_mc_path('full',family,seed,n,reps)
selected <- NULL
if (length(args)==5L) {
  if (!identical(args[[5L]],'heldout')) stop('Unknown partition')
  grid <- partition_regimes(build_contamination_grid(ga_config),
                            ga_config$training_fraction,42L)
  selected <- as.integer(grid$scenario_id[grid$partition=='heldout'])
  if (!length(selected)) stop('Empty predeclared heldout partition')
}
t2_publish_scenario_store(path,family,seed,selected)
verified <- t2_verify_scenario_store(path,family,seed,selected)
if (!nrow(verified)) stop('Empty scientific manifest')
cat('Scenario store verified:',nrow(verified),'scenarios\n')
