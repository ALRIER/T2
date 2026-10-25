#!/usr/bin/env Rscript
# Prueba T2 Version 3 B3: external scoring on immutable, independently
# catalogued datasets. Explicitly proxy-estimand (complete-series mean).
a<-commandArgs(trailingOnly=TRUE)
if(length(a)<2L)stop('Usage: PROFILE_BATCH_DIRECTORY FAMILY [smoke]')
batchdir<-a[[1L]];family<-a[[2L]]
smoke<-length(a)>2L&&identical(a[[3L]],'smoke')
if(!family%in%c('normal','lognormal','weibull','invgauss','exgaussian','exwald'))stop('Invalid family')
source('R/00_shared/load_all.R');t2_load('.')
source('R/00_shared/pipeline.R')
source('R/00_shared/v3_inference.R')
if(!dir.exists(batchdir))stop('Missing audited batch: ',batchdir)
profile<-read.csv(file.path(batchdir,'profiles.csv'),stringsAsFactors=FALSE)
profile<-profile[profile$load_ok %in% TRUE,,drop=FALSE]
if(smoke) profile<-head(profile,1L)
if(!nrow(profile))stop('No valid external dataset in batch')
root<-file.path('artifacts','realworld_T2_V3_B3',family,basename(batchdir))
dir.create(root,recursive=TRUE,showWarnings=FALSE)
outfile<-file.path(root,'scores_T2_V3_B3.csv')
inferfile<-file.path(root,'paired_inference_T2_V3_B3.csv')
if(file.exists(outfile))file.remove(outfile)
if(file.exists(inferfile))file.remove(inferfile)
rows<-0L
train_seeds<-if(smoke)0L else 0:9
for(j in seq_len(nrow(profile))) {
  id<-profile$dataset_id[j]
  raw<-file.path(batchdir,'raw',paste0(id,'.rds'))
  if(!file.exists(raw))stop('Missing audited raw: ',id)
  if(!identical(unname(tools::md5sum(raw)),profile$raw_sha256[j]))stop('Raw audit fingerprint mismatch: ',id)
  x<-readRDS(raw);x<-as.numeric(x);x<-x[is.finite(x)]
  if(length(x)<150L)stop('Insufficient parent observations: ',id)
  for(n in if(smoke)200L else c(200L,1000L)) {
    R<-if(smoke)20L else 500L
    set.seed(t2_seed(paste('B3',family,id,n),18517L))
    T<-matrix(NA_real_,R,26L,dimnames=list(NULL,ESTIMATOR_NAMES))
    for(i in seq_len(R))T[i,]<-component_vector(sample(x,n,replace=TRUE))
    if(any(!is.finite(T)))stop('Invalid component scores')
    sc<-list(T=T,target=mean(x),scenario_id=j)
    baselines<-lapply(ESTIMATOR_NAMES,function(nm)new_frozen_model(nm,component=nm))
    for(k in train_seeds) {
      p<-file.path('artifacts','discovery_v3',family,sprintf('seed%02d',k),'discovery.rds')
      if(!file.exists(p))stop('Missing frozen Discovery model: ',p)
      fit<-readRDS(p)
      if(length(fit$engines)!=4L)stop('Invalid frozen engines')
      candidates<-Filter(function(m)!is.null(m$weights),fit$models)
      models<-c(baselines,candidates)
      if(anyDuplicated(vapply(models,function(m)m$id,character(1))))stop('Duplicate candidates')
      z<-score_model_set(T,models,mean(x))
      z$dataset_id<-id;z$parent_dataset_id<-profile$parent_dataset_id[j]
      z$family<-family;z$training_seed<-k;z$sample_n<-n
      z$depth<-'full';z$target_type<-'full_parent_empirical_mean_proxy'
      z$raw_md5<-profile$raw_sha256[j];z$weights_sha256<-t2_sha256(p)
      write.table(z,outfile,sep=',',append=rows>0L,col.names=rows==0L,row.names=FALSE)
      set.seed(t2_seed(paste('B3_infer',family,id,n,k),19000L))
      inf<-t2_v3_infer_scenario(sc,models,k,j,n,B=if(smoke)50L else 500L)
      inf$dataset_id<-id;inf$family<-family;inf$target_type<-'full_parent_empirical_mean_proxy'
      write.table(inf,inferfile,sep=',',append=rows>0L,col.names=rows==0L,row.names=FALSE)
      rows<-rows+1L;rm(z,inf,fit,models,candidates)
    }
    rm(T,sc,baselines);invisible(gc(verbose=FALSE))
  }
  rm(x);invisible(gc(verbose=FALSE))
}
writeLines(c('Prueba T2 version 3 B3',
             'Full-parent empirical mean is a proxy target, not known population truth',
             'Repeated samples from the same parent dataset are dependent',
             'Real-world false-positive rate is not identifiable without a valid null-generating mechanism',
             'Per-dataset paired intervals are descriptive; parent-level confirmatory aggregation is separate',
             'Original raw fingerprint and frozen Discovery weights were checked'),
           file.path(root,'scientific_scope_T2_V3_B3.txt'))
source('R/00_shared/t2_v3_b3_naming.R')
# Already suffixed output names are preserved, no rewriting of original raw artifacts.
cat('T2_V3_B3_REALWORLD_SCORING_PASS',family,basename(batchdir),rows,'comparisons\n')
