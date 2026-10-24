t2_q95_ci_v3 <- function(candidate_errors,reference_errors,B=500L,seed=1L) {
 x<-as.numeric(candidate_errors); y<-as.numeric(reference_errors)
 stopifnot(length(x)==length(y),length(x)>=30L,B>=200L,
           all(is.finite(x)),all(is.finite(y)),all(x>=0),all(y>=0))
 set.seed(seed)
 q<-function(z)unname(stats::quantile(z,.95,type=8))
 boot<-replicate(B,{
  i<-sample.int(length(x),length(x),replace=TRUE)
  c(q(x[i]),q(x[i])-q(y[i]))
 })
 ci<-t(apply(boot,1,stats::quantile,probs=c(.025,.975),type=8))
 list(q95=q(x),q95_lower=ci[1,1],q95_upper=ci[1,2],
      delta=q(x)-q(y),delta_lower=ci[2,1],delta_upper=ci[2,2],
      method="paired_replicate_bootstrap",B=B)
}
