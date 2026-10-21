args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript tools/extended_mc.R FAMILY SEED_INDEX")
family <- args[[1L]]
seed_index <- suppressWarnings(as.integer(args[[2L]]))
families <- c("normal","lognormal","weibull","invgauss","exgaussian","exwald")
if (!family %in% families || is.na(seed_index) || !seed_index %in% 9:20)
  stop("Expected one of the six canonical families and a new seed index from 9 to 20")
source("R/00_shared/load_all.R")
t2_load(".")
t2_check_runtime(".", strict = TRUE)
source("R/00_shared/pipeline.R")
if (seed_index %in% c(ga_config$training_seed_indices, ga_config$heldout_seed_index))
  stop("New seed overlaps training or reserved held-out index")
path <- t2_mc_path("full", family, seed_index,
                   ga_config$train_n, ga_config$evaluation_replicates)
t2_canonical_mc("full", family, seed_index,
                ga_config$train_n, ga_config$evaluation_replicates)
if (!file.exists(path)) stop("Canonical output was not written")
x <- t2_read_rds(path)
if (!identical(as.integer(x$seed_index), seed_index) ||
    !identical(x$family, family) ||
    !identical(as.integer(x$n), as.integer(ga_config$train_n)) ||
    !identical(as.integer(x$replications), as.integer(ga_config$evaluation_replicates)))
  stop("Canonical Monte Carlo verification mismatch")
cat("EXTENDED MC PASS", family, seed_index, path, "\n")
