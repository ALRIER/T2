#!/usr/bin/env Rscript
# Contract for revised 26-component library (v2): complete real-valued samples.
source("R/00_shared/load_all.R"); t2_load(".")
stopifnot(length(ESTIMATOR_NAMES)==26L,
          identical(ESTIMATOR_NAMES[4:5],c("trimmed10","winsorized_0.15")),
          !any(c("harmonic","geometric") %in% ESTIMATOR_NAMES))
x<-c(-12,-9,-5,-2,0,1,3,7,10,18,25)
a<-component_vector(x)
stopifnot(all(is.finite(a)),length(a)==26L,
          abs(a[["trimmed10"]]-mean(x,trim=.1))<1e-12,
          abs(a[["winsorized_0.15"]]-winsorized_mean_safe(x,.15))<1e-12)
for(shift in c(-100,0,100)) {
 y<-component_vector(x+shift)
 stopifnot(abs(y[["trimmed10"]]-(a[["trimmed10"]]+shift))<1e-10,
           abs(y[["winsorized_0.15"]]-(a[["winsorized_0.15"]]+shift))<1e-10)
}
stopifnot(all(is.finite(component_vector(-abs(x)-1))),
          all(admissible_estimator_mask("normal")),
          all(admissible_estimator_mask("lognormal")),
          identical(colnames(component_matrix(list(x,-x,x+10))),ESTIMATOR_NAMES))
# Convexity resides in weights and allows signed component outputs.
w<-rep(1/26,26); tmat<-component_matrix(list(x,-x,x+10))
stopifnot(all(is.finite(model_predict(tmat,new_frozen_model("contract",weights=w)))),
          abs(sum(w)-1)<1e-12)
cat("REVISED_ESTIMATOR_LIBRARY_CONTRACT_PASS\n")
