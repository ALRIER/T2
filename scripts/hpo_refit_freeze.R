#!/usr/bin/env Rscript
# Experimental final refit: selected HPO configuration -> eight frozen weights/family/engine.
# No test, confirmatory, heldout, or real-world data access.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=3L)stop("Usage: Rscript scripts/hpo_refit_freeze.R family engine best_trial.json")
family<-args[1];engine<-args[2];best_path<-args[3]
stopifnot(family%in%c("normal","lognormal","weibull","invgauss","exgaussian","exwald"),
          engine%in%c("ga","nsga2","de","dirichlet"))
if(!requireNamespace("jsonlite",quietly=TRUE))stop("jsonlite is required")
b<-jsonlite::fromJSON(best_path)
if(!identical(b$status,"pilot_only_not_confirmatory"))stop("Unknown HPO provenance")
if(!identical(b$family,family)||!identical(b$engine,engine))stop("HPO identity mismatch")
source("R/00_shared/load_all.R");t2_load(".");source("R/00_shared/pipeline.R")
source("R/02_discovery/domain_randomization.R")
cfg<-ga_config;p<-b$best_params
cfg$population<-as.integer(p$population);cfg$generations<-as.integer(p$generations)
cfg$patience<-as.integer(p$patience);cfg$improvement<-as.numeric(p$improvement)
if(!is.null(p$mutation_rate))cfg$mutation_rate<-as.numeric(p$mutation_rate)
if(!is.null(p$crossover_probability))cfg$crossover_probability<-as.numeric(p$crossover_probability)
outdir<-file.path("artifacts","hpo_v1","refit",family,engine)
dir.create(outdir,recursive=TRUE,showWarnings=FALSE)
n_random<-as.integer(Sys.getenv("T2_DR_SCENARIOS","120"))
R<-as.integer(Sys.getenv("T2_DR_REPS","500"))
for(seed in 0:7){
  # Fresh training-only randomization in each refit seed; never sample from test suite.
  z<-t2_dr_scenarios(family,seed,n=1000L,R=R,n_scenarios=n_random)
  search_seed<-t2_seed(paste("hpo_refit",family,engine,seed),25101L)
  d<-switch(engine,
    ga=ga_discover(z$scenarios,cfg,seed=search_seed,shard=NULL),
    nsga2=nsga_discover(z$scenarios,cfg,seed=search_seed,shard=NULL),
    de=de_discover(z$scenarios,cfg,seed=search_seed,F=as.numeric(p$F),CR=as.numeric(p$CR),shard=NULL),
    dirichlet=dirichlet_discover(z$scenarios,cfg,seed=search_seed,
       n_draws=as.integer(p$n_draws),alpha=as.numeric(p$alpha),shard=NULL))
  O<-d$objectives
  scales<-pmax(colMeans(abs(O)),1e-12)
  index<-which.min(rowSums(sweep(O,2L,scales,"/")))
  w<-as.numeric(d$weights[,index])
  stopifnot(length(w)==26L,all(is.finite(w)),all(w>=0),abs(sum(w)-1)<1e-7)
  id<-sprintf("%s_%s_train%02d",family,engine,seed)
  path<-file.path(outdir,paste0(id,".csv"))
  if(file.exists(path))stop("Refusing to overwrite an existing frozen candidate: ",path)
  write.csv(data.frame(component=ESTIMATOR_NAMES,weight=w),path,row.names=FALSE)
  saveRDS(list(model_id=id,config=cfg,hyperparameters=p,
    discovery_seed=seed,training_randomization=z$design,
    parent_parameters=z$params,selected_objectives=O[index,],
    protocol="experimental_hpo_refit_v1_not_confirmatory"),
    file.path(outdir,paste0(id,".provenance.rds")))
}
cat("FROZEN_PILOT_COMPLETE ",family," ",engine,"\n",sep="")
