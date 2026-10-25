#!/usr/bin/env Rscript
args<-commandArgs(TRUE)
if(length(args)!=2L)stop('Usage: FAMILY SEED')
fam<-args[1];seed<-as.integer(args[2])
if(is.na(seed)||!seed%in%0:9)stop('Invalid seed')
if(!requireNamespace('jsonlite',quietly=TRUE))stop('jsonlite required')
source('R/00_shared/load_all.R');t2_load('.')
source('R/00_shared/pipeline.R')
source('R/00_shared/v3_scientific_adapter.R')
source('R/00_shared/v3_downstream.R')
root<-file.path('artifacts','T2_V3_B3_discovery_cv5_refit',fam,sprintf('seed%02d',seed))
selected<-list()
for(engine in c('ga','nsga2','de','dirichlet')){
 trials<-lapply(1:5,function(fold){
  p<-file.path('artifacts','T2_V3_B3_nested_optuna',fam,sprintf('seed%02d',seed),
    sprintf('fold%02d',fold),paste0(engine,'_best.json'))
  if(!file.exists(p))stop('Missing strict inner HPO evidence: ',p)
  jsonlite::fromJSON(p)
 })
 scores<-vapply(trials,function(x)x$best_score,numeric(1))
 chosen<-trials[[which.min(scores)]]$best_params
 selected[[engine]]<-chosen
}
data<-t2_v3_discovery_input(fam,seed,selected=0:120)
engines<-list()
for(engine in names(selected)){
 p<-selected[[engine]]
 cfg<-ga_config
 cfg$population<-as.integer(p$population)
 cfg$generations<-as.integer(p$generations)
 cfg$mutation_rate<-as.numeric(p$mutation_rate)
 cfg$crossover_probability<-as.numeric(p$crossover_probability)
 cfg$discovery_weight_regularization_lambda<-as.numeric(p$regularization_lambda)
 rng<-t2_seed(paste('B3_final',fam,seed,engine),8121L)
 engines[[engine]]<-switch(engine,
 ga=ga_discover(data$scenarios,cfg,seed=rng,shard=NULL),
 nsga2=nsga_discover(data$scenarios,cfg,seed=rng,shard=NULL),
 de=de_discover(data$scenarios,cfg,seed=rng,F=p$F,CR=p$CR,shard=NULL),
 dirichlet=dirichlet_discover(data$scenarios,cfg,seed=rng,
 alpha=p$alpha,n_draws=cfg$population*cfg$generations,shard=NULL))
}
fit<-list(engines=engines,models=t2_models(engines),config=ga_config,
 nested_cv='5x3',role='full_discovery_refit',source='T2_V3_B3')
stopifnot(length(fit$engines)==4L)
out<-file.path('artifacts','discovery_v3',fam,sprintf('seed%02d',seed))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
saveRDS(fit,file.path(out,'discovery.rds'))
write.csv(data.frame(family=fam,seed=seed,folds_external=5L,folds_internal=3L,
 engine=names(selected),parameter_source='five_independent_inner_HPO_fits',
 stringsAsFactors=FALSE),file.path(out,'promotion_manifest.csv'),row.names=FALSE)
cat('T2_V3_B3_PROMOTED_FINAL_W_PASS',fam,seed,'\n')
