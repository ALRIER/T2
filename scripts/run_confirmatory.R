#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L)
  stop('Usage: Rscript scripts/run_confirmatory.R STAGE [full|smoke] [family] [confirm_seed]')
stage <- args[[1L]]
mode <- if (length(args) >= 2L) args[[2L]] else 'full'
family <- if (length(args) >= 3L) args[[3L]] else 'all'
confirm_seed <- if (length(args) >= 4L) as.integer(args[[4L]]) else NA_integer_
valid_stages <- c('preflight', 'montecarlo', 'score', 'inference',
                  'realworld_score', 'realworld_inference', 'report')
if (!stage %in% valid_stages) stop('Invalid confirmatory stage')
if (!mode %in% c('smoke', 'full')) stop('Invalid confirmatory mode')
source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
t2_check_runtime('.', strict = TRUE)

if (stage == 'preflight') {
  z <- t2_confirmatory_preflight(mode)
  if (file.exists(file.path('config', 'confirmatory_public_datasets.csv')))
    t2_confirmatory_realworld_manifest()
  print(z)
  quit(save = 'no', status = if (identical(z$status, 'PASS')) 0L else 1L)
}
if (family == 'all' && !stage %in% c('realworld_score', 'realworld_inference', 'report'))
  stop('A family is required for ', stage)
if (stage %in% c('montecarlo', 'score', 'inference') && !family %in% t2_families())
  stop('Invalid family')
if (stage %in% c('montecarlo', 'score') && !is.finite(confirm_seed))
  stop('A confirmatory seed is required for ', stage)
if (stage %in% c('montecarlo', 'score') && !confirm_seed %in% t2_confirmatory_seeds(mode))
  stop('Seed is not in the confirmatory protocol: ', confirm_seed)

if (stage == 'montecarlo') {
  for (n in t2_confirmatory_sizes(mode)) {
    t2_confirmatory_mc(family, confirm_seed, n, t2_confirmatory_reps(mode),
                       mode = mode, generate = TRUE)
  }
} else if (stage == 'score') {
  t2_confirmatory_score_block(family, confirm_seed, mode = mode)
} else if (stage == 'inference') {
  t2_confirmatory_inference(family, mode = mode)
} else if (stage == 'realworld_score') {
  t2_confirmatory_realworld_score(mode = mode)
} else if (stage == 'realworld_inference') {
  t2_confirmatory_realworld_inference(mode = mode)
} else if (stage == 'report') {
  t2_confirmatory_report(mode = mode)
}
cat('CONFIRMATORY', stage, family, if (is.finite(confirm_seed)) confirm_seed else '', 'COMPLETE\n')
