#!/usr/bin/env Rscript
# Experimental final refit: selected HPO configuration -> three candidate roles per discovery seed.
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
source("R/02_discovery/three_candidate_selection.R")
cfg<-ga_config;p<-b$best_params
cfg$population<-as.integer(p$population);cfg$generations<-as.integer(p$generations)
cfg$patience<-as.integer(p$patience);cfg$improvement<-as.numeric(p$improvement)
if(!is.null(p$mutation_rate))cfg$mutation_rate<-as.numeric(p$mutation_rate)
if(!is.null(p$crossover_probability))cfg$crossover_probability<-as.numeric(p$crossover_probability)
outdir<-file.path("artifacts","hpo_v1","refit",family,engine)
dir.create(outdir,recursive=TRUE,showWarnings=FALSE)
n_random<-as.integer(Sys.getenv("T2_DR_SCENARIOS","120"))
R<-as.integer(Sys.getenv("T2_DR_REPS","500"))
for(seed in t2_seed_plan_v3$discovery){
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
  selections<-t2_select_three_candidates(d$weights,O)
  for(j in seq_len(nrow(selections))) {
    role<-selections$role[j]
    index<-selections$candidate_index[j]
    w<-as.numeric(d$weights[,index])
    stopifnot(length(w)==26L,all(is.finite(w)),all(w>=0),abs(sum(w)-1)<1e-7)
    id<-sprintf("%s_%s_train%02d_%s",family,engine,seed,role)
    path<-file.path(outdir,paste0(id,".csv"))
    provenance_path<-file.path(outdir,paste0(id,".provenance.rds"))
    if(file.exists(path)||file.exists(provenance_path))
      stop("Refusing to overwrite frozen candidate: ",id)
    write.csv(data.frame(component=ESTIMATOR_NAMES,weight=w),path,row.names=FALSE)
    saveRDS(list(model_id=id,role=role,status="candidate_unconfirmed",
       config=cfg,hyperparameters=p,discovery_seed=seed,
       training_randomization=z$design,parent_parameters=z$params,
       selected_objectives=O[index,],
       selection_rule="pareto_minima_and_normalized_ideal_distance_v1",
       protocol="experimental_hpo_refit_v2_not_confirmatory"),
       provenance_path)
  }
}
cat("FROZEN_PILOT_COMPLETE ",family," ",engine,"\n",sep="")
