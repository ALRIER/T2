#!/usr/bin/env Rscript
# Small standalone v3 generation and isolation test; no historical canonical call.
source("R/00_shared/load_all.R");t2_load(".")
source("R/00_shared/pipeline.R")
source("R/01_monte_carlo/v3_generation.R")
stopifnot(identical(sort(unlist(t2_seed_plan_v3[c("discovery","heldout","stress")],use.names=FALSE)),0:19))
for(stage in c("discovery","heldout","stress")) {
 index<-t2_seed_plan_v3[[stage]][1]
 d<-t2_v3_design(stage,"normal",index,1000L,16L)
 stopifnot(nrow(d$grid)==17L,!anyDuplicated(d$grid$scenario_id),
           sum(d$grid$rate==0)==1L,
           all(d$grid$rate[-1L]>0),
           setequal(unique(d$grid$mechanism[-1L]),ga_config$contamination_types))
}
D<-lapply(c("discovery","heldout","stress"),function(stage){
 index<-t2_seed_plan_v3[[stage]][1]
 t2_v3_design(stage,"normal",index,1000L,16L)$grid
})
stopifnot(any(D[[2]]$domain=="in_domain"),
          any(D[[2]]$domain=="out_of_domain"),
          max(D[[1]]$rate[-1])<min(D[[3]]$rate[-1]),
          max(D[[1]]$scale[-1])<min(D[[3]]$scale[-1]))
stopifnot(!identical(t2_seed_for_v3("discovery","normal",0L,1000L),
                     t2_seed_for_v3("heldout","normal",10L,1000L)))
tmp<-tempfile("v3_smoke_")
z<-t2_v3_generate("discovery","normal",0L,1000L,R=2L,n_scenarios=8L,root=tmp)
stopifnot(identical(z$component_names,ESTIMATOR_NAMES),
          length(z$scenarios)==9L,nrow(z$grid)==9L,
          all(vapply(z$scenarios,function(x)
             identical(colnames(x$T),ESTIMATOR_NAMES)&&
             identical(dim(x$T),c(2L,26L)),logical(1))))
zz<-t2_v3_generate("discovery","normal",0L,1000L,R=2L,n_scenarios=8L,root=tmp)
stopifnot(identical(z$grid,zz$grid),identical(z$scenarios,zz$scenarios))
unlink(tmp,recursive=TRUE)
cat("V3_ROLE_GENERATOR_TEST_PASS\n")
