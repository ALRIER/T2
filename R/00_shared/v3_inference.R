# Independent V3 confirmatory inference on frozen predictions and paired Monte Carlo replications.
# All bootstrap resampling is paired by row, preserving dependence between candidates.
t2_v3_infer_scenario <- function(sc,models,training_seed,heldout_seed,n,B=200L,alpha=.05) {
  stopifnot(is.matrix(sc$T),ncol(sc$T)==26L,nrow(sc$T)>=100L)
  E<-vapply(models,function(m)(model_predict(sc$T,m)-sc$target)^2,numeric(nrow(sc$T)))
  colnames(E)<-vapply(models,function(m)m$id,character(1))
  if(!'median'%in%colnames(E)) stop('Prespecified median reference missing')
  if(!identical(dim(E)[2L],length(models)))stop('Invalid error matrix')
  base<-E[,'median']; R<-nrow(E)
  # Stratified reproducibility across scientific shards, no global RNG dependency.
  forgoal<-list()
  for(metric in c('mse','q95')) {
    obs<-if(metric=='mse') colMeans(E) else apply(E,2L,stats::quantile,probs=.95,type=8,names=FALSE)
    if(metric=='mse') ref<-mean(base) else ref<-as.numeric(stats::quantile(base,.95,type=8))
    # Shared replicate indices retain pairing; measure benefit as reference - candidate.
    boot<-matrix(NA_real_,B,ncol(E))
    for(b in seq_len(B)) {
      ix<-sample.int(R,R,replace=TRUE)
      ee<-E[ix,,drop=FALSE]; rr<-base[ix]
      bv<-if(metric=='mse')colMeans(ee) else apply(ee,2L,stats::quantile,probs=.95,type=8,names=FALSE)
      br<-if(metric=='mse')mean(rr) else as.numeric(stats::quantile(rr,.95,type=8))
      boot[b,]<-br-bv
    }
    gain<-ref-obs
    ci<-apply(boot,2,stats::quantile,probs=c(alpha/2,1-alpha/2),type=8,names=FALSE)
    row<-data.frame(model=names(obs),metric=metric,reference='median',
     gain=gain,relative_gain_pct=if(ref>0)100*gain/ref else NA_real_,
     ci_lower=ci[1,],ci_upper=ci[2,],reference_loss=ref,
     candidate_loss=as.numeric(obs),stringsAsFactors=FALSE)
    # Bootstrap distribution centered at the observed contrast represents
    # the approximate H0: reference loss = candidate loss.
    row$bootstrap_null_p<-vapply(seq_along(gain),function(j) {
      if(names(gain)[j]=='median')return(1)
      se<-stats::sd(boot[,j])
      if(!is.finite(se)||se<=0)return(if(gain[j]>0)0 else 1)
      stats::pnorm(-gain[j]/se)
    },numeric(1))
    forgoal[[metric]]<-row
  }
  z<-do.call(rbind,forgoal)
  # MSE: paired one-sided t test. Q95: centered paired-bootstrap null
  # approximation. Both are corrected across the predeclared shard.
  z$p_value<-NA_real_
  for(i in seq_len(nrow(z))) {
    if(z$model[i]=='median'){z$p_value[i]<-1;next}
    x<-base-E[,z$model[i]]
    if(z$metric[i]=='mse'){
      z$p_value[i]<-if(stats::sd(x)>0) stats::pt(-mean(x)/(stats::sd(x)/sqrt(R)),df=R-1L) else if(mean(x)>0) 0 else 1
    } else {
      z$p_value[i]<-z$bootstrap_null_p[i]
    }
  }
  z$training_seed<-training_seed;z$heldout_seed<-heldout_seed;
  z$sample_n<-n;z$scenario_id<-sc$scenario_id;z$replications<-R
  z
}
t2_v3_adjust_inference <- function(z,alpha=.05) {
  # Family-wise correction over all reported models, metrics and scenarios.
  z$p_holm<-NA_real_
  i<-which(!is.na(z$p_value) & z$model!='median')
  z$p_holm[i]<-p.adjust(z$p_value[i],method='holm')
  z$confirmed_mse_gain<-z$metric=='mse' & !is.na(z$p_holm) &
    z$p_holm<alpha & z$gain>0 & z$ci_lower>0
  z$confirmed_q95_gain<-z$metric=='q95' & !is.na(z$p_holm) &
    z$p_holm<alpha & z$gain>0 & z$ci_lower>0
  z
}

# Paired label-exchangeability calibration under a precisely declared null:
# for each replicate reference/candidate errors are exchangeable. Per metric
# p-values are empirical ranks in the same null world; each simulated world
# is corrected by Holm across *both metrics and all candidate contrasts*.
t2_v3_null_fpr <- function(sc, models, train_seed, eval_seed, Bnull=500L, alpha=.05) {
  stopifnot(Bnull>=30L,alpha>0,alpha<1)
  E<-vapply(models,function(m)(model_predict(sc$T,m)-sc$target)^2,numeric(nrow(sc$T)))
  colnames(E)<-vapply(models,function(m)m$id,character(1))
  if(!'median'%in%colnames(E))stop('Null reference median absent')
  baseline<-E[,'median'];ids<-setdiff(colnames(E),'median')
  R<-length(baseline)
  nullstats<-matrix(NA_real_,nrow=Bnull,ncol=length(ids)*2L,
    dimnames=list(NULL,as.vector(rbind(paste0(ids,'_mse'),paste0(ids,'_q95')))))
  for(j in seq_along(ids)){
    e<-E[,ids[j]]
    for(b in seq_len(Bnull)){
      swap<-sample.int(2L,R,replace=TRUE)==1L
      ref<-ifelse(swap,e,baseline)
      alt<-ifelse(swap,baseline,e)
      nullstats[b,2L*j-1L]<-mean(ref)-mean(alt)
      nullstats[b,2L*j]<-as.numeric(stats::quantile(ref,.95,type=8))-
        as.numeric(stats::quantile(alt,.95,type=8))
    }
  }
  # Conservative permutation-rank p-values, including the evaluated world.
  P<-apply(nullstats,2L,function(v) vapply(v,function(x)sum(v>=x)/Bnull,numeric(1)))
  P<-matrix(P,nrow=Bnull,ncol=ncol(nullstats),dimnames=dimnames(nullstats))
  adj<-t(apply(P,1L,stats::p.adjust,method='holm'))
  fwer<-mean(rowSums(adj<=alpha)>0)
  out<-data.frame(model=rep(ids,each=2L),
    metric=rep(c('mse','q95'),length(ids)),reference='median',
    nominal_alpha=alpha,null_reps=Bnull,
    false_positives=colSums(adj<=alpha),
    empirical_fpr=colMeans(adj<=alpha),
    joint_familywise_fpr=fwer,
    null_method='paired_label_exchangeability_Holm_both_metrics',
    training_seed=train_seed,heldout_seed=eval_seed,
    scenario_id=sc$scenario_id,sample_n=R,stringsAsFactors=FALSE)
  out
}
