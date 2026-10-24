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
    forgoal[[metric]]<-row
  }
  z<-do.call(rbind,forgoal)
  # MSE: paired one-sided t test for mean error reduction. q95 uses paired
  # bootstrap inversion as an exploratory test, flagged separately.
  z$p_value<-NA_real_
  for(i in seq_len(nrow(z))) {
    if(z$model[i]=='median'){z$p_value[i]<-1;next}
    x<-base-E[,z$model[i]]
    if(z$metric[i]=='mse'){
      z$p_value[i]<-if(stats::sd(x)>0) stats::pt(-mean(x)/(stats::sd(x)/sqrt(R)),df=R-1L) else if(mean(x)>0) 0 else 1
    } else {
      z$p_value[i]<-NA_real_
    }
  }
  z$training_seed<-training_seed;z$heldout_seed<-heldout_seed;
  z$sample_n<-n;z$scenario_id<-sc$scenario_id;z$replications<-R
  z
}
t2_v3_adjust_inference <- function(z,alpha=.05) {
  # Family-wise multiplicity correction across candidate/scenario tests for MSE.
  z$p_holm<-NA_real_
  i<-which(z$metric=='mse' & !is.na(z$p_value) & z$model!='median')
  z$p_holm[i]<-p.adjust(z$p_value[i],method='holm')
  z$confirmed_mse_gain<-z$metric=='mse' & !is.na(z$p_holm) &
    z$p_holm<alpha & z$gain>0 & z$ci_lower>0
  # Quantile CI is descriptive; no confirmatory q95 p test implemented here.
  z$confirmed_q95_gain<-FALSE
  z
}

# Diagnostic null calibration: randomly swap candidate/reference error labels
# per Monte Carlo replicate under the exchangeability null. It estimates the
# type-I rejection rate of the unadjusted one-sided paired test.
t2_v3_null_fpr <- function(sc, models, train_seed, eval_seed, Bnull=100L, alpha=.05) {
  E<-vapply(models,function(m)(model_predict(sc$T,m)-sc$target)^2,numeric(nrow(sc$T)))
  colnames(E)<-vapply(models,function(m)m$id,character(1))
  base<-E[,'median'];R<-length(base)
  result<-lapply(setdiff(colnames(E),'median'),function(nm) {
    d<-base-E[,nm]
    rejections<-rep(FALSE,Bnull)
    for(b in seq_len(Bnull)) {
      swapped<-sample(c(-1,1),R,replace=TRUE)*d
      sd0<-stats::sd(swapped)
      p<-if(sd0>0) stats::pt(-mean(swapped)/(sd0/sqrt(R)),df=R-1L) else 1
      rejections[b]<-is.finite(p)&&p<alpha
    }
    data.frame(model=nm,reference='median',null_method='paired_random_swap',
      nominal_alpha=alpha,null_reps=Bnull,false_positives=sum(rejections),
      empirical_fpr=mean(rejections),training_seed=train_seed,
      heldout_seed=eval_seed,scenario_id=sc$scenario_id,sample_n=R,
      stringsAsFactors=FALSE)
  })
  do.call(rbind,result)
}
