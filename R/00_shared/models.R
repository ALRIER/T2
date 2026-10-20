# Common interface: all engines receive the SAME prepared R x 26 component matrix.
# Mean / median / trimmed20 / Huber are the initial four baseline controls;
# additional learned competitors can register a frozen weight vector with a name.
reference_models <- function() c('mean','median','trimmed20','huber')
assert_model_registry <- function() {
  stopifnot(exists('ESTIMATOR_REGISTRY'), length(ESTIMATOR_REGISTRY)==26L,
            all(reference_models() %in% names(ESTIMATOR_REGISTRY)))
  invisible(TRUE)
}
new_frozen_model <- function(id, weights=NULL, component=NULL, family=NULL) {
  stopifnot(is.character(id),length(id)==1L, nzchar(id))
  if(!is.null(weights)) { stopifnot(length(weights)==26L,all(is.finite(weights)),all(weights>=0),sum(weights)>0);weights<-weights/sum(weights) }
  if(is.null(weights) && is.null(component)) stop('Model requires weights or component')
  list(id=id,weights=weights,component=component,family=family)
}
reference_model_set <- function() lapply(reference_models(),function(nm)new_frozen_model(nm,component=nm))
model_predict <- function(T,model,eligible=rep(TRUE,26L)) {
  stopifnot(is.matrix(T),ncol(T)==26L,all(is.finite(T)))
  if(!is.null(model$weights)) return(drop(T%*%normalize_weights(matrix(model$weights,26L),eligible)))
  ix<-match(model$component,colnames(T))
  if(is.na(ix)) ix<-match(model$component,ESTIMATOR_NAMES)
  if(is.na(ix)||!eligible[ix]) stop(paste('Blocked/missing component',model$component))
  T[,ix]
}
score_model_set <- function(T,models,target,eligible=rep(TRUE,26L)) {
  stopifnot(is.finite(target),length(target)==1L)
  do.call(rbind,lapply(models,function(model){
    e<-(model_predict(T,model,eligible)-target)^2
    data.frame(model=model$id,mse=mean(e),q95=unname(quantile(e,.95,type=8)),
               n_rep=length(e),stringsAsFactors=FALSE)
  }))
}
# Numeric sample-level interface, used by Monte Carlo, heldout, and external data.
component_vector <- function(x) {
  x<-as.numeric(x);x<-x[is.finite(x)]
  if(length(x)<5L) stop('At least five finite observations needed')
  vapply(ESTIMATOR_REGISTRY,function(fun){
    z<-tryCatch(as.numeric(fun(x))[1],error=function(e) NA_real_)
    if(!is.finite(z)) stop('Estimator returned nonfinite component')
    z
  },numeric(1L))
}
component_matrix <- function(samples) {
  out<-t(vapply(samples,component_vector,numeric(26L)))
  colnames(out)<-ESTIMATOR_NAMES
  out
}
