#!/usr/bin/env Rscript
# Independent canonical Monte Carlo generation for the prospective seed plan.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=4L)stop("Usage: Rscript scripts/v3_montecarlo_stage.R ROLE FAMILY SEED N")
role<-args[1];family<-args[2];index<-as.integer(args[3]);n<-as.integer(args[4])
source("R/00_shared/load_all.R");t2_load(".");source("R/00_shared/pipeline.R")
t2_assert_seed_plan_v3()
if(!role %in% c("discovery","heldout","stress"))stop("Invalid role")
if(!index %in% t2_seed_plan_v3[[role]])stop("Seed not assigned to requested role")
if(!n %in% if(role=="discovery")1000L else c(200L,1000L,3000L))
 stop("Sample size not assigned to requested role")
# Cache namespace segregates the revised 26-column library from historical matrices.
Sys.setenv(T2_CANONICAL_MC_ROOT="artifacts/mc_v3_real26")
replications<-as.integer(Sys.getenv("T2_V3_REPS","500"))
if(replications<2L)stop("At least two replications required")
# The stage-specific shard ensures non-overlapping contamination streams.
shard<-sprintf("v3_%s_%s_%02d_n%d",role,family,index,n)
old<-t2_mc_version
t2_mc_version<-function() "v3_real26_seedplan20"
# Canonical generator uses role-separated directory and role-specific seed identifiers.
# Avoid passing legacy seed streams to anything outside this stage.
mc<-t2_canonical_mc("full",family,index,n,replications)
stopifnot(identical(mc$family,family),identical(as.integer(mc$n),n))
cat(sprintf("GENERATED %s %s seed%02d n%d; archive: %s\n",
            role,family,index,n,t2_mc_path("full",family,index,n,replications)))
