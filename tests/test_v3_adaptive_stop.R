#!/usr/bin/env Rscript
source("R/02_discovery/adaptive_stop.R")
cfg<-list(early_stop_enabled=TRUE,generations=80L,patience=8L,max_patience=20L,
          min_generations=24L,stop_window=6L,improvement=.001)
stopifnot(!t2_adaptive_stop(rep(1,12),12L,cfg))
stopifnot(!t2_adaptive_stop(rep(1,23),23L,cfg))
stopifnot(t2_adaptive_stop(rep(1,30),15L,cfg))
cfg$early_stop_enabled<-FALSE
stopifnot(!t2_adaptive_stop(rep(1,80),80L,cfg))
cat("V3_ADAPTIVE_STOP_CONTRACT_PASS\n")
