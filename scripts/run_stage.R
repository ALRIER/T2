args <- commandArgs(trailingOnly=TRUE)
if(length(args)<2L)stop('Usage: Rscript scripts/run_stage.R STAGE SHARD [smoke|full] [family] [seed_index] [engine]')
stage<-args[1];shard<-args[2];mode<-if(length(args)>2L)args[3] else 'smoke'
family<-if(length(args)>3L)args[4] else 'normal';seed_index<-if(length(args)>4L)as.integer(args[5]) else 0L
engine<-if(length(args)>5L)args[6] else 'all'
if(!stage%in%c('preflight','datasets','mc_validation','montecarlo','discovery','heldout','realworld','stress','aggregate'))stop('Invalid stage')
if(!grepl('^[a-zA-Z0-9_-]{1,64}$',shard))stop('Invalid shard')
if(!mode%in%c('smoke','full'))stop('Invalid mode')
if(!family%in%t2_families())stop('Invalid family')
if(!engine%in%c('all','nsga2','de','dirichlet'))stop('Invalid engine')
source('R/00_shared/load_all.R');t2_load('.')
source('R/00_shared/pipeline.R')
run_t2_stage(stage,shard,mode,family,seed_index,engine)
