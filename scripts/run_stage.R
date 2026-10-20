args <- commandArgs(trailingOnly=TRUE)
if(length(args)<2L)stop('Usage: Rscript scripts/run_stage.R STAGE SHARD [smoke|full]')
stage<-args[1];shard<-args[2];mode<-if(length(args)>2L)args[3] else 'smoke'
if(!stage%in%c('preflight','datasets','mc_validation','montecarlo','discovery','heldout','realworld','stress','aggregate'))stop('Invalid stage')
if(!grepl('^[a-zA-Z0-9_-]{1,64}$',shard))stop('Invalid shard')
if(!mode%in%c('smoke','full'))stop('Invalid mode')
source('R/00_shared/load_all.R');t1_load('.')
source('R/00_shared/pipeline.R')
run_t1_stage(stage,shard,mode)
