#!/usr/bin/env Rscript
# Regime-matched external scoring.  All frozen W* are evaluated separately;
# structural matching is calculated before, and independently of, performance.
args <- commandArgs(trailingOnly=TRUE)
stage <- if(length(args)) args[[1L]] else stop('Usage: match|score|infer [batch]')
batch <- if(length(args)>1L) as.integer(args[[2L]]) else NA_integer_
root <- Sys.getenv('RW2_ROOT', 'artifacts/realworld_regime_matched_v2/scoring')
data_root <- Sys.getenv('RW2_DATA_ROOT', file.path(root,'data','T2_rw2_external_catalog_664'))
source('R/00_shared/load_all.R'); t2_load('.'); source('R/00_shared/pipeline.R')
dir.create(root, recursive=TRUE, showWarnings=FALSE)
families <- c('normal','lognormal','weibull','invgauss','exgaussian','exwald')
relation <- function(f,p) {
 direct <- switch(f, normal=p=='normal_like', lognormal=p=='lognormal_like', weibull=p=='weibull_like',
   invgauss=p %in% c('lognormal_like','weibull_like'), exgaussian=p %in% c('normal_like','lognormal_like'),
   exwald=p %in% c('lognormal_like','weibull_like'))
 near <- switch(f, normal=p=='empirical_unknown', lognormal=p=='weibull_like', weibull=p=='lognormal_like',
   invgauss=p=='empirical_unknown', exgaussian=p %in% c('weibull_like','empirical_unknown'), exwald=p=='empirical_unknown')
 if(isTRUE(direct)) 'direct_intraregime' else if(isTRUE(near)) 'near_intrfamily' else 'crossfamily_transfer'
}
benchmark <- function(p) if(p=='normal_like') 'mean' else if(p=='empirical_unknown') 'huber' else 'trimmed20'
depth_vectors <- function(x) {
 q <- quantile(x,c(.1,.75,.9),na.rm=TRUE,type=8)
 out <- list(full=x, body_10_90=x[x>=q[1] & x<=q[3]])
 tail <- x[x>=q[2]]; if(length(tail)>=150L) out$upper_tail <- tail
 out[vapply(out,length,integer(1))>=150L]
}
if(stage=='match') {
 p <- file.path(data_root,'profile_registry.csv'); if(!file.exists(p)) stop('Profile registry missing')
 x <- read.csv(p,stringsAsFactors=FALSE); x <- x[x$load_ok %in% TRUE,,drop=FALSE]
 rows <- do.call(rbind,lapply(families,function(f) transform(x,source_family=f,proximity_layer=vapply(empirical_profile,function(p)relation(f,p),character(1)))))
 rows$matching_rule <- 'v2_profile_anchor_pre_score_v1'
 write.csv(rows,file.path(root,'regime_match_manifest.csv'),row.names=FALSE)
 writeLines('RW2_MATCH_COMPLETE',file.path(root,'match.status')); cat('MATCH',nrow(rows),'rows\n')
} else if(stage=='score') {
 if(!is.finite(batch) || batch<1L) stop('Score requires batch')
 m <- read.csv(file.path(root,'regime_match_manifest.csv'),stringsAsFactors=FALSE)
 ids <- sort(unique(m$dataset_id)); groups <- split(ids, ceiling(seq_along(ids)/10)); ids <- groups[[batch]]
 if(is.null(ids)) stop('Unknown score batch')
 reps <- as.integer(Sys.getenv('RW2_REPS','500')); ns <- as.integer(strsplit(Sys.getenv('RW2_SAMPLE_SIZES','200|1000'),'|',fixed=TRUE)[[1]])
 ans <- list(); k <- 0L
 for(id in ids) {
  raw <- file.path(data_root,'raw',paste0(id,'.rds')); if(!file.exists(raw)) stop('Missing immutable raw input: ',id)
  x <- readRDS(raw); sub <- m[m$dataset_id==id,,drop=FALSE]
  for(depth in names(depth_vectors(x))) {
   xx <- depth_vectors(x)[[depth]]; prep <- realworld_prepare(xx,sample_sizes=ns,R=reps,seed=t2_seed(paste(id,depth),15001L))
   for(f in families) {
    zf <- sub[sub$source_family==f,,drop=FALSE]; mods <- t2_confirmatory_load_models(f)
    ref <- mods$reference[[match(benchmark(zf$empirical_profile[1]),vapply(mods$reference,`[[`,character(1),'component'))]]
    for(z in prep) {
     bse <- (model_predict(z$T,ref)-z$target)^2
     for(mid in names(mods$candidates)) {
      se <- (model_predict(z$T,mods$candidates[[mid]])-z$target)^2; k<-k+1L
      ans[[k]] <- data.frame(parent_dataset_id=zf$parent_dataset_id[1],dataset_id=id,source_family=f,
       proximity_layer=zf$proximity_layer[1],empirical_profile=zf$empirical_profile[1],depth=depth,sample_n=z$sample_n,
       model_id=mid,engine=sub(sprintf('^%s_',f),'',sub('_train[0-9]+$','',mid)),
       mse_difference=mean(se)-mean(bse),q95_difference=unname(quantile(se,.95,type=8)-quantile(bse,.95,type=8)),
       benchmark_mse=mean(bse),benchmark_q95=unname(quantile(bse,.95,type=8)),stringsAsFactors=FALSE)
     }
    }
   }
  }
 }
 out <- do.call(rbind,ans); d <- file.path(root,sprintf('scores_batch_%03d',batch)); dir.create(d,recursive=TRUE,showWarnings=FALSE)
 saveRDS(out,file.path(d,'scores.rds')); write.csv(out,file.path(d,'scores.csv'),row.names=FALSE); writeLines('RW2_SCORE_COMPLETE',file.path(d,'score.status'))
} else if(stage=='infer') {
 fs <- list.files(root,'scores.rds$',recursive=TRUE,full.names=TRUE); if(!length(fs)) stop('No score shards')
 x <- do.call(rbind,lapply(fs,readRDS));
 # Depth and sample sizes are repeated measurements, averaged before parent-level inference.
 b <- aggregate(cbind(mse_difference,q95_difference,benchmark_mse,benchmark_q95)~parent_dataset_id+source_family+proximity_layer+model_id+engine,x,mean)
 key <- interaction(b$source_family,b$proximity_layer,b$model_id,drop=TRUE)
 out <- do.call(rbind,lapply(split(b,key),function(z) {
  a<-t2_confirmatory_block_test(z$mse_difference,t2_confirmatory_bootstrap_B('full'),t2_seed(paste(z$source_family[1],z$proximity_layer[1],z$model_id[1],'mse'),16001L))
  q<-t2_confirmatory_block_test(z$q95_difference,t2_confirmatory_bootstrap_B('full'),t2_seed(paste(z$source_family[1],z$proximity_layer[1],z$model_id[1],'q95'),16002L))
  data.frame(source_family=z$source_family[1],proximity_layer=z$proximity_layer[1],model_id=z$model_id[1],engine=z$engine[1],n_parent=nrow(z),mse_difference=a['difference'],mse_ci_high=a['ci_high'],mse_p_value=a['p_value'],q95_difference=q['difference'],q95_ci_high=q['ci_high'],q95_p_value=q['p_value'],benchmark_mse=mean(z$benchmark_mse),benchmark_q95=mean(z$benchmark_q95))
 }))
 out$mse_q_value<-ave(out$mse_p_value,out$proximity_layer,FUN=function(p)p.adjust(p,'BH')); out$q95_q_value<-ave(out$q95_p_value,out$proximity_layer,FUN=function(p)p.adjust(p,'BH'))
 out$mse_supported<-out$mse_difference<0 & out$mse_ci_high<0 & out$mse_q_value<=.05; out$q95_supported<-out$q95_difference<0 & out$q95_ci_high<0 & out$q95_q_value<=.05
 out$taxonomy<-ifelse(out$mse_supported & out$q95_supported,'mse_and_q95_bh_fdr',ifelse(out$mse_supported,'mse_only_bh_fdr',ifelse(out$q95_supported,'q95_only_bh_fdr','no_supported_gain')))
 out$mse_gain_pct<- -100*out$mse_difference/pmax(out$benchmark_mse,1e-12); out$q95_gain_pct<- -100*out$q95_difference/pmax(out$benchmark_q95,1e-12)
 write.csv(out,file.path(root,'realworld_v2_taxonomy.csv'),row.names=FALSE); writeLines('RW2_INFERENCE_COMPLETE',file.path(root,'inference.status'))
} else stop('Unknown stage')
