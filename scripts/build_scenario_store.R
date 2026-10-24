#!/usr/bin/env Rscript
# Convert one archived canonical block to an independent immutable scenario store.
# Usage: Rscript scripts/build_scenario_store.R FAMILY SEED N REPS
args <- commandArgs(trailingOnly=TRUE)
if (length(args)!=4L) stop('Usage: FAMILY SEED N REPS')
family <- args[[1L]]; seed <- as.integer(args[[2L]])
n <- as.integer(args[[3L]]); reps <- as.integer(args[[4L]])
if (anyNA(c(seed,n,reps)) || n<1L || reps<1L) stop('Invalid canonical block coordinates')
source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
source('R/00_shared/scenario_store.R')
if (!family %in% t2_families()) stop('Unsupported family')
path <- t2_mc_path('full',family,seed,n,reps)
t2_publish_scenario_store(path,family,seed)
verified <- t2_verify_scenario_store(path,family,seed)
if (!nrow(verified)) stop('Empty scientific manifest')
cat('Scenario store verified:',nrow(verified),'scenarios\n')
