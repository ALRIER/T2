source('R/00_shared/load_all.R');t2_load('.')
set.seed(11);T<-matrix(rnorm(80L*26L),80L,26L);colnames(T)<-ESTIMATOR_NAMES
W<-matrix(rexp(26*6),26,6);A<-evaluate_weights(T,W,0);
stopifnot(nrow(A$objectives)==6L, all(is.finite(A$objectives)))
S<-list(list(T=T,target=0,band='clean',eligible=rep(TRUE,26L)),list(T=T,target=0,band='low',eligible=rep(TRUE,26L)),list(T=T,target=0,band='intermediate',eligible=rep(TRUE,26L)),list(T=T,target=0,band='high',eligible=rep(TRUE,26L)))
cfg<-ga_config;cfg$population<-8L;cfg$generations<-2L;cfg$patience<-2L
a<-nsga_discover(S,cfg,seed=2);b<-de_discover(S,cfg,seed=2);c<-dirichlet_discover(S,cfg,seed=2,n_draws=20L)
stopifnot(ncol(a$weights)>=1L,ncol(b$weights)>=1L,ncol(c$weights)>=1L)
mods<-c(reference_model_set(),list(new_frozen_model('nsga_candidate',weights=a$weights[,1]),new_frozen_model('de_candidate',weights=b$weights[,1]),new_frozen_model('dirichlet_candidate',weights=c$weights[,1])))
comp<-model_comparison_table(T,mods,0,stage='discovery',B=100L)
stopifnot(nrow(comp)==length(mods),all(is.finite(comp$q_value)),all(comp$evidence_type=='exploratory'))
stopifnot(is.finite(paired_q95_bootstrap((T[,1])^2,(T[,2])^2,100L)$difference))
cat('Integration v4 integration smoke test: PASS\n')
