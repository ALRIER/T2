#!/usr/bin/env Rscript
source("R/00_shared/load_all.R");t2_load(".")
source("R/00_shared/pipeline.R")
source("R/02_discovery/domain_randomization.R")
a<-t2_dr_design(seed=71,n_scenarios=24L)
b<-t2_dr_design(seed=71,n_scenarios=24L)
stopifnot(identical(a,b),nrow(a)==25L,sum(a$rate==0)==1L,
          all(a$rate[-1L]>.004),all(a$rate[-1L]<.301),
          all(a$scale[-1L]>=1.5),all(a$scale[-1L]<=30),
          setequal(unique(a$mechanism[-1L]),ga_config$contamination_types))
for(f in t2_families()) {
  p<-t2_dr_family_params(f,21L)
  stopifnot(is.finite(analytic_mean_from_params(f,p)))
}
# Tiny execution validates the entire real matrix-estimator route without training.
x<-t2_dr_scenarios("normal",31L,n=60L,R=3L,n_scenarios=8L)
stopifnot(length(x$scenarios)==9L,
          all(vapply(x$scenarios,function(z)
          identical(dim(z$T),c(3L,26L)) && all(is.finite(z$T)),logical(1))))
cat("HPO_DOMAIN_RANDOMIZATION_TEST_PASS\n")
