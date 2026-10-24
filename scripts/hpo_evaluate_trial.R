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
if(!fold %in% 1:3 || !seed %in% 0:9)stop("Invalid fold or seed")
# Grouped 3-fold validation holds out complete contamination mechanisms.
# All severity and contamination-rate variants of each mechanism are assigned together.
# This prevents a search from seeing the same mechanism at a neighboring MAD value.
source("R/01_monte_carlo/v3_generation.R")
replications<-as.integer(Sys.getenv("T2_HPO_REPS","500"))
n_scenarios<-as.integer(Sys.getenv("T2_V3_SCENARIOS","120"))
mc<-t2_v3_generate("discovery",family,seed,1000L,
                     R=replications,n_scenarios=n_scenarios)
grid<-mc$grid
mechanism_folds<-list(
 c("upper_tail","clustered_upper","point_mass"),
 c("lower_tail","clustered_symmetric","mixture_bimodal_near"),
 c("symmetric_t","mixture_bimodal_far"))
stopifnot(setequal(unlist(mechanism_folds),ga_config$contamination_types),
          !anyDuplicated(unlist(mechanism_folds)))
fold_id<-integer(nrow(grid))
for(j in seq_along(mechanism_folds))
 fold_id[grid$mechanism%in%mechanism_folds[[j]]]<-j
stopifnot(all(fold_id[grid$rate>0]%in%1:3))
train_ids<-grid$scenario_id[fold_id!=fold]
valid_ids<-grid$scenario_id[fold_id==fold]
stopifnot(!length(intersect(train_ids,valid_ids)),length(valid_ids)>0L,0L%in%train_ids)
stopifnot(!any(grid$mechanism[grid$scenario_id%in%valid_ids] %in%
               grid$mechanism[grid$scenario_id%in%train_ids]))
training<-mc$scenarios[match(train_ids,grid$scenario_id)]
validation<-mc$scenarios[match(valid_ids,grid$scenario_id)]
cfg<-ga_config;cfg$population<-as.integer(params$population);cfg$generations<-as.integer(params$generations)
cfg$patience<-as.integer(params$patience);cfg$max_patience<-cfg$patience+as.integer(params$patience_extension)
cfg$min_generations<-as.integer(ceiling(cfg$generations*params$warmup_fraction))
cfg$stop_window<-as.integer(params$stop_window);cfg$early_stop_enabled<-TRUE;cfg$improvement<-as.numeric(params$improvement)
cfg$mutation_rate<-as.numeric(if(is.null(params$mutation_rate))ga_config$mutation_rate else params$mutation_rate)
cfg$crossover_probability<-as.numeric(if(is.null(params$crossover_probability))ga_config$crossover_probability else params$crossover_probability)
stopifnot(cfg$population>=8L,cfg$generations>=1L,cfg$patience>=1L)
# Disable checkpoint writes during trial search to avoid reusing states across configurations.
trial_seed<-t2_seed_for_v3("discovery",family,seed,1000L,scenario_id=-100L-fold,
                                replicate=as.integer(sum(utf8ToInt(paste(engine,basename(params_path))))))
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
