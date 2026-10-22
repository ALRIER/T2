args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=2L) stop("Usage: Rscript tools/independent_validation_data.R FAMILY SEED")
family <- args[[1]]
seed <- suppressWarnings(as.integer(args[[2]]))
if(!family %in% c("normal","lognormal","weibull","invgauss","exgaussian","exwald") ||
   is.na(seed) || !seed %in% 21:26)
  stop("Expected canonical family and reserved validation seed 21..26")
source("R/00_shared/load_all.R"); t2_load(".")
t2_check_runtime(".",strict=TRUE)
source("R/00_shared/pipeline.R")
if(seed %in% c(ga_config$training_seed_indices,ga_config$heldout_seed_index,9:20))
 stop("Validation seed overlaps existing train, heldout, or expanded MC seeds")
for(n in ga_config$heldout_n) {
  x<-t2_canonical_mc("full",family,seed,n,ga_config$evaluation_replicates)
  stopifnot(identical(x$family,family),identical(as.integer(x$seed_index),seed),
            identical(as.integer(x$n),as.integer(n)))
  cat("HELDOUT INPUT PASS",family,seed,n,"\n")
}
stress_n <- as.integer(Sys.getenv("T2_STRESS_SAMPLE_N","1000"))
stress_reps <- as.integer(Sys.getenv("T2_STRESS_REPS","250"))
x<-t2_canonical_mc("full",family,seed,stress_n,stress_reps)
stopifnot(identical(x$family,family),identical(as.integer(x$seed_index),seed))
cat("STRESS INPUT PASS",family,seed,stress_n,stress_reps,"\n")
