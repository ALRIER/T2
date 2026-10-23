#!/usr/bin/env Rscript
# Experimental HPO evaluator. Offline: reads existing discovery Monte Carlo T matrices.
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=5L) stop("Usage: Rscript scripts/hpo_evaluate_trial.R engine family params.json fold seed")
engine<-args[1];family<-args[2];params_path<-args[3];fold<-as.integer(args[4]); seed<-as.integer(args[5])
if(!engine %in% c("ga","nsga2","de","dirichlet"))stop("Invalid engine")
if(!family %in% c("normal","lognormal","weibull","invgauss","exgaussian","exwald"))stop("Invalid family")
if(!requireNamespace("jsonlite",quietly=TRUE))stop("Install jsonlite")
params<-jsonlite::fromJSON(params_path,simplifyVector=TRUE)
source("R/00_shared/load_all.R");t2_load(".");source("R/00_shared/pipeline.R")
if(!fold %in% 1:3 || !seed %in% 0:7)stop("Invalid fold or seed")
# Grouped 3-fold validation holds out complete contamination mechanisms.
# All severity and contamination-rate variants of each mechanism are assigned together.
# This prevents a search from seeing the same mechanism at a neighboring MAD value.
grid<-build_contamination_grid(ga_config)
stopifnot(nrow(grid)==361L)
mechanism_folds<-list(
  c("upper_tail","clustered_upper","point_mass"),
  c("lower_tail","clustered_symmetric","mixture_bimodal_near"),
  c("symmetric_t","mixture_bimodal_far")
)
stopifnot(setequal(unlist(mechanism_folds),ga_config$contamination_types),
          !anyDuplicated(unlist(mechanism_folds)))
fold_id<-integer(nrow(grid))
for(j in seq_along(mechanism_folds))
  fold_id[grid$mechanism %in% mechanism_folds[[j]]]<-j
stopifnot(fold_id[grid$rate==0]==0L,all(fold_id[grid$rate>0]%in%1:3))
train_ids<-grid$scenario_id[fold_id!=fold]
valid_ids<-grid$scenario_id[fold_id==fold]
stopifnot(!length(intersect(train_ids,valid_ids)),length(valid_ids)>0L,1L%in%train_ids)
stopifnot(!any(grid$mechanism[grid$scenario_id%in%valid_ids] %in%
               grid$mechanism[grid$scenario_id%in%train_ids]))
# Use precomputed discovery-only simulation streams; no confirmation/real world reads.
replications<-as.integer(Sys.getenv("T2_HPO_REPS","500"))
mc<-t2_canonical_mc("full",family,seed,1000L,replications)
training<-mc$scenarios[train_ids];validation<-mc$scenarios[valid_ids]
cfg<-ga_config;cfg$population<-as.integer(params$population);cfg$generations<-as.integer(params$generations)
cfg$patience<-as.integer(params$patience);cfg$improvement<-as.numeric(params$improvement)
cfg$mutation_rate<-as.numeric(if(is.null(params$mutation_rate))ga_config$mutation_rate else params$mutation_rate)
cfg$crossover_probability<-as.numeric(if(is.null(params$crossover_probability))ga_config$crossover_probability else params$crossover_probability)
stopifnot(cfg$population>=8L,cfg$generations>=1L,cfg$patience>=1L)
# Disable checkpoint writes during trial search to avoid reusing states across configurations.
trial_seed<-t2_seed(paste("hpo",engine,family,fold,seed,basename(params_path)),6001L)
res<-switch(engine,
 ga=ga_discover(training,cfg,seed=trial_seed,shard=NULL),
 nsga2=nsga_discover(training,cfg,seed=trial_seed,shard=NULL),
 de=de_discover(training,cfg,seed=trial_seed,F=as.numeric(params$F),CR=as.numeric(params$CR),shard=NULL),
 dirichlet=dirichlet_discover(training,cfg,seed=trial_seed,n_draws=as.integer(params$n_draws),alpha=as.numeric(params$alpha),shard=NULL))
O<-res$objectives;W<-res$weights
stopifnot(is.matrix(W),nrow(W)==26L,nrow(O)==ncol(W),all(W>=0),all(is.finite(W)))
sc<-pmax(colMeans(abs(O)),1e-12);index<-which.min(rowSums(sweep(O,2L,sc,"/")))
w<-W[,index,drop=FALSE]
stopifnot(abs(sum(w)-1)<1e-8)
# Validate scenario means directly, without requiring each validation fold to contain every band.
metrics<-t(vapply(validation,function(x)as.numeric(evaluate_weights(x$T,w,x$target)$objectives[1,]),numeric(2)))
# Compare against the same parent sample mean reference for each validation scenario.
refs<-t(vapply(validation,function(x){
 e<-(x$T[,1L]-x$target)^2
 c(mean(e),unname(quantile(e,.95,type=8)))
},numeric(2)))
ratios<-metrics/pmax(refs,1e-12)
out<-list(engine=engine,family=family,fold=fold,seed=seed,
 mse=mean(metrics[,1]),q95=mean(metrics[,2]),
 mse_ratio=mean(ratios[,1]),q95_ratio=mean(ratios[,2]),
 n_validation_scenarios=length(validation),
 heldout_mechanisms=mechanism_folds[[fold]],
 generations_ran=if(is.null(res$generations_ran))0 else res$generations_ran)
cat(jsonlite::toJSON(out,auto_unbox=TRUE,digits=12),"\n")
