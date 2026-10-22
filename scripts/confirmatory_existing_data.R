#!/usr/bin/env Rscript
# Score yesterday's immutable canonical Monte Carlo artifacts with the original 192 frozen models.
# Only seeds 21:26 enter the PRIMARY confirmation; seeds 9:20 contain n=1000 training-sized T matrices
# and may be used as a separately labelled SECONDARY sensitivity analysis.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)<2L) stop("Usage: Rscript scripts/confirmatory_existing_data.R score|inference|audit FAMILY [SEED]")
stage<-args[1L]; family<-args[2L]
if(!stage %in% c("score","inference","audit")) stop("Unsupported stage")
source("R/00_shared/load_all.R"); t2_load(".")
source("R/00_shared/pipeline.R")
t2_check_runtime(".",strict=TRUE)
if(!family %in% t2_families()) stop("Invalid family")
# Override only the seed declaration and MC loader. The scoring/inference machinery is unchanged.
t2_confirmatory_seeds <- function(mode="full") if(identical(mode,"smoke")) 21L else 21:26
t2_confirmatory_mc <- function(family,confirm_seed,n,replications,mode="full",generate=FALSE) {
 if(isTRUE(generate)) stop("Regeneration prohibited: use downloaded canonical data")
 if(!confirm_seed %in% 21:26) stop("Validation seed must be reserved 21..26")
 path<-t2_mc_path("full",family,confirm_seed,n,replications)
 if(!file.exists(path)) stop("Missing canonical artifact: ",path)
 x<-t2_read_rds(path)
 if(!identical(x$family,family) || !identical(as.integer(x$seed_index),as.integer(confirm_seed)) ||
    !identical(as.integer(x$n),as.integer(n)) ||
    !identical(as.integer(x$replications),as.integer(replications)) ||
    !identical(x$mc_version,t2_mc_version()) ||
    length(x$scenarios)!=361L || !identical(x$grid,build_contamination_grid(ga_config)))
     stop("Canonical data provenance or scenario grid mismatch: ",path)
 if(!all(vapply(x$scenarios,function(s) is.matrix(s$T)&&nrow(s$T)==replications,logical(1))))
     stop("Canonical matrices malformed: ",path)
 x$confirm_seed<-as.integer(confirm_seed)
 x
}
if(stage=="audit") {
 for(seed in 21:26) for(n in ga_config$heldout_n)
    t2_confirmatory_mc(family,seed,n,ga_config$evaluation_replicates,generate=FALSE)
 cat("CANONICAL AUDIT PASS",family,"\n")
} else if(stage=="score") {
 if(length(args)!=3L) stop("Score requires seed")
 seed<-as.integer(args[3L])
 if(is.na(seed)||!seed %in% 21:26) stop("Invalid reserved seed")
 t2_confirmatory_score_block(family,seed,mode="full")
 cat("CANONICAL CONFIRMATORY SCORE PASS",family,seed,"\n")
} else {
 t2_confirmatory_inference(family,mode="full")
 cat("CANONICAL CONFIRMATORY INFERENCE PASS",family,"\n")
}
