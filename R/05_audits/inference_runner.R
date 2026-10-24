t2_inference <- function(T,models,target,stage,seed) {
 model_comparison_table(T,models,target,benchmark_id='mean',stage=stage,B=ga_config$bootstrap_B,seed=seed)
}

t2_run_aggregate <- function(shard){
 d<-t2_require(shard,'discovery');h<-t2_require(shard,'heldout');r<-t2_require(shard,'realworld');s<-t2_require(shard,'stress')
 t2_validate_W(d$models)
 stopifnot(length(d$models)>4L,nrow(h$scores)>0L,nrow(r$scores)>0L,nrow(s$scores)>0L)
 lapply(list(h$scores,r$scores,s$scores),t2_validate_scores)
 lapply(list(heldout=h,realworld=r,stress=s),function(z)stopifnot(all(c('model','mse','q95')%in%names(z$scores))))
 list(stage='aggregate',results=list(heldout=h$scores,realworld=r$scores,stress=s$scores),fixture_realworld=isTRUE(r$fixture),fixture_stress=isTRUE(s$fixture))
}
