#!/usr/bin/env Rscript
a<-commandArgs(trailingOnly=TRUE)
if(length(a)<4L)stop('Usage: heldout|stress FAMILY SEED N [smoke]')
role<-a[[1]];fam<-a[[2]];seed<-as.integer(a[[3]]);n<-as.integer(a[[4]])
smoke<-length(a)>=5L&&identical(a[[5]],'smoke')
if(!role%in%c('heldout','stress'))stop('Invalid role')
if(!seed%in%if(role=='heldout')10:14 else 15:19)stop('Illegal evaluation seed')
if(!n%in%c(200L,1000L,3000L))stop('Illegal sample size')
source('R/00_shared/load_all.R');t2_load('.')
source('R/00_shared/pipeline.R')
source('R/00_shared/v3_scientific_adapter.R')
source('R/00_shared/v3_downstream.R')
source('R/00_shared/v3_inference.R')
out<-file.path('artifacts','v3_confirmatory_inference',role,fam,sprintf('seed%02d_n%d',seed,n))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
rows<-list();nulls<-list();k<-0L
for(training_seed in if(smoke)0L else 0:9){
  p<-file.path('artifacts/discovery_v3',fam,sprintf('seed%02d',training_seed),'discovery.rds')
  if(!file.exists(p))stop('Missing frozen Discovery: ',p)
  fit<-readRDS(p);if(length(fit$engines)!=4L)stop('Incomplete engines')
  models<-fit$models
  for(id in if(smoke)c(0L,1L,120L) else 0:120) {
    sc<-t2_v3_read_scenario(role,fam,seed,n,id)
    set.seed(t2_seed(paste(role,fam,seed,n,training_seed,id),9001L))
    z<-t2_v3_infer_scenario(sc,models,training_seed,seed,n,B=if(smoke)50L else 200L)
    z$role<-role;z$family<-fam;z$discovery_sha256<-t2_sha256(p)
    k<-k+1L;rows[[k]]<-z
    if(id==0L) {
      nulls[[length(nulls)+1L]]<-t2_v3_null_fpr(sc,models,training_seed,seed,
        Bnull=if(smoke)30L else 200L)
    }
  }
}
tab<-t2_v3_adjust_inference(do.call(rbind,rows))
write.csv(tab,file.path(out,'paired_inference.csv'),row.names=FALSE)
nulltab<-do.call(rbind,nulls)
write.csv(nulltab,file.path(out,'null_calibration.csv'),row.names=FALSE)
if(any(!is.finite(tab$ci_lower))||any(!is.finite(tab$ci_upper)))stop('Incomplete intervals')
if(!all(c('mse','q95')%in%tab$metric)||!nrow(nulltab))stop('Missing inference layer')
writeLines(c(sprintf('role=%s',role),sprintf('family=%s',fam),
 sprintf('evaluation_seed=%d',seed),sprintf('sample_n=%d',n),
 sprintf('training_seeds=%d',if(smoke)1L else 10L),
 sprintf('scenarios=%d',if(smoke)3L else 121L),
 'mse_inference=paired_t_holm_and_bootstrap_interval',
 'q95_inference=paired_bootstrap_interval_exploratory',
 'null_diagnostic=paired_random_swap_clean_scenario',
 'inferential_completeness=q95_confirmatory_and_global_FPR_pending'),
 file.path(out,'protocol.txt'))
cat('V3_INFERENCE_SHARD_PASS',role,fam,seed,n,nrow(tab),'rows\n')
