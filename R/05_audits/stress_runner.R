# Frozen-model stress tests, with NO training or weight update.
# The original validation suite is archived in legacy_sources for auditability.
stress_run_models <- function(data_generator,models,conditions,
                              R=200L,n=c(200L,1000L,3000L),seed=501L) {
  stopifnot(is.function(data_generator),length(models)>0L)
  rows<-list();k<-0L
  for(s in seq_len(nrow(conditions))) for(nn in n){
    # CRN: all competing models see same samples in this setting.
    set.seed(seed + s*1000L + nn)
    samples<-lapply(seq_len(R),function(r)data_generator(conditions[s,,drop=FALSE],nn))
    T<-component_matrix(samples)
    target<-attr(conditions,'true_mean')
    if(is.null(target) && 'true_mean' %in% names(conditions)) target<-conditions$true_mean[s]
    if(is.null(target)||length(target)!=1L||!is.finite(target))
      stop('Generator must supply known true mean via condition metadata')
    y<-score_model_set(T,models,target)
    y$scenario_id<-if('scenario_id'%in%names(conditions)) conditions$scenario_id[s] else s
    y$sample_n<-nn;k<-k+1L;rows[[k]]<-y
  }
  do.call(rbind,rows)
}
stress_diagnostics <- function(results) {
  aggregate(cbind(mse,q95)~model+sample_n,data=results,FUN=function(v)c(mean=mean(v),max=max(v)))
}
