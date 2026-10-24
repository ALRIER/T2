#!/usr/bin/env Rscript
source("R/00_shared/load_all.R");t2_load(".")
source("R/00_shared/pipeline.R")
source("R/01_monte_carlo/v3_generation.R")
stopifnot(identical(t2_v3_indices("heldout"),10:14))
d<-t2_v3_design("heldout","normal",10L,200L,16L)$grid
stopifnot(sum(d$domain=="in_domain")==8L,
          sum(d$domain=="out_of_domain")==8L,
          sum(d$domain=="clean")==1L)
set.seed(4)
e<-rexp(100);b<-rexp(100,rate=1.05)
x<-t2_q95_ci_v3(e,b,B=200L,seed=120L)
stopifnot(all(is.finite(unlist(x[1:6]))),x$q95_lower<=x$q95,
          x$q95<=x$q95_upper)
cat("V3_HELDOUT_Q95_CONTRACT_PASS\n")
