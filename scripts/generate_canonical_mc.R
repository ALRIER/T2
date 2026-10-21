args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L)
  stop('Usage: Rscript scripts/generate_canonical_mc.R MODE FAMILY SEED_INDEX')
mode <- args[1]
family <- args[2]
seed_index <- as.integer(args[3])
if (!mode %in% c('smoke', 'full')) stop('Invalid mode')
if (!family %in% c('normal','lognormal','weibull','invgauss','exgaussian','exwald')) stop('Invalid family')
if (!is.finite(seed_index) || seed_index < 0L || seed_index > 8L) stop('Invalid seed index')
source('R/00_shared/load_all.R'); t2_load('.')
t2_check_runtime('.', strict = TRUE)
source('R/00_shared/pipeline.R')

if (mode == 'smoke') {
  t2_canonical_mc(mode, family, seed_index, 30L, 30L)
} else if (seed_index == t2_heldout_seed_index()) {
  for (n in ga_config$heldout_n)
    t2_canonical_mc(mode, family, seed_index, n, ga_config$evaluation_replicates)
  stress_n <- as.integer(Sys.getenv('T2_STRESS_SAMPLE_N', '1000'))
  stress_r <- as.integer(Sys.getenv('T2_STRESS_REPS', '250'))
  t2_canonical_mc(mode, family, seed_index, stress_n, stress_r)
} else {
  t2_canonical_mc(mode, family, seed_index, ga_config$train_n, ga_config$evaluation_replicates)
}
cat('CANONICAL MC PASS', mode, family, seed_index, '\n')
