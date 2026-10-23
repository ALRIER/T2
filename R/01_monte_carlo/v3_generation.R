# Versioned, stage-specific prospective Monte Carlo design.
# Disjoint parameter intervals prevent test-set reuse during development.
t2_v3_design <- function(role,family,index,n,n_scenarios=120L) {
 stopifnot(role%in%c("discovery","heldout","stress"),
           index%in%t2_seed_plan_v3[[role]],family%in%t2_families(),
           n_scenarios>=8L)
 boundaries<-switch(role,
   discovery=list(rate=c(.005,.20),mad=c(1.5,12),perturb=.15),
   heldout=list(rate=c(.205,.30),mad=c(12.5,30),perturb=.22),
   stress=list(rate=c(.305,.40),mad=c(30.5,50),perturb=.30))
 set.seed(t2_seed_for_v3(role,family,index,n,-1L))
 mechanisms<-sample(rep(ga_config$contamination_types,length.out=n_scenarios))
 tab<-data.frame(
   scenario_id=seq_len(n_scenarios),
   rate=runif(n_scenarios,boundaries$rate[1],boundaries$rate[2]),
   scale=exp(runif(n_scenarios,log(boundaries$mad[1]),log(boundaries$mad[2]))),
   mechanism=mechanisms,stringsAsFactors=FALSE)
 tab<-rbind(data.frame(scenario_id=0L,rate=0,scale=NA_real_,
                       mechanism="none",stringsAsFactors=FALSE),tab)
 stopifnot(nrow(tab)==n_scenarios+1L)
 list(grid=tab,bounds=boundaries,protocol="v3_continuous_role_disjoint")
}
t2_v3_params <- function(role,family,index,n,strength) {
 set.seed(t2_seed_for_v3(role,family,index,n,-2L))
 p<-t2_params(family)
 positive<-intersect(names(p),c("sd","sdlog","shape","scale","mean","sigma","tau","lambda","rate"))
 for(k in positive)if(p[[k]]>0) p[[k]]<-p[[k]]*exp(runif(1L,-strength,strength))
 if("meanlog"%in%names(p))p$meanlog<-p$meanlog+runif(1,-strength,strength)
 if("mu"%in%names(p))p$mu<-p$mu+runif(1,-strength,strength)
 p
}
t2_v3_generate <- function(role,family,index,n,R=500L,n_scenarios=120L,
                           root="artifacts/mc_v3_real26") {
 if(!role%in%c("discovery","heldout","stress")||
    !index%in%t2_seed_plan_v3[[role]])stop("Unassigned stage seed")
 if(!n%in%if(role=="discovery")1000L else c(200L,1000L,3000L))
   stop("Invalid stage sample size")
 if(R<2L||n_scenarios<8L)stop("Invalid simulation size")
 design<-t2_v3_design(role,family,index,n,n_scenarios)
 params<-t2_v3_params(role,family,index,n,design$bounds$perturb)
 target<-analytic_mean_from_params(family,params)
 folder<-file.path(root,"v3_real26_seedplan20",role,family,
                  sprintf("seed%02d",index),sprintf("n%s_r%s",n,R))
 dir.create(folder,recursive=TRUE,showWarnings=FALSE)
 canonical<-file.path(folder,"canonical.rds")
 if(file.exists(canonical)) {
   z<-readRDS(canonical)
   if(!identical(z$protocol,"v3_real26_seedplan20")||
      !identical(z$grid,design$grid)||
      !identical(z$component_names,ESTIMATOR_NAMES))stop("Incompatible checkpoint")
   return(z)
 }
 base_file<-file.path(folder,"base_samples.rds")
 if(file.exists(base_file))base<-readRDS(base_file) else {
   set.seed(t2_seed_for_v3(role,family,index,n,-3L))
   base<-vapply(seq_len(R),function(k)generate_population(family,n,params),numeric(n))
   t2_atomic_save(base,base_file)
 }
 if(!identical(dim(base),c(as.integer(n),as.integer(R))))stop("Base pool shape mismatch")
 sc<-vector("list",nrow(design$grid))
 for(i in seq_len(nrow(design$grid))) {
   row<-design$grid[i,,drop=FALSE]
   piece<-file.path(folder,sprintf("scenario_%04d.rds",row$scenario_id))
   if(file.exists(piece)) {
     z<-readRDS(piece)
     if(!identical(z$component_names,ESTIMATOR_NAMES)||
        !identical(z$scenario_id,row$scenario_id)||
        !identical(z$rate,row$rate)||!identical(z$scale,row$scale)||
        !identical(z$mechanism,row$mechanism))stop("Scenario checkpoint mismatch")
   } else {
     set.seed(t2_seed_for_v3(role,family,index,n,row$scenario_id))
     samples<-lapply(seq_len(R),function(k){
       x<-base[,k]
       if(row$rate>0) x<-inject_outliers_realistic(x,row$rate,row$scale,row$mechanism)
       x
     })
     T<-component_matrix(samples)
     if(!identical(colnames(T),ESTIMATOR_NAMES)||any(!is.finite(T)))
       stop("Invalid revised component matrix")
     z<-list(T=T,target=target,scenario_id=row$scenario_id,
       rate=row$rate,scale=row$scale,mechanism=row$mechanism,
       band=if(row$rate==0)"clean" else if(row$rate<=.05)"low" else
         if(row$rate<=.1)"intermediate" else "high",
       component_names=ESTIMATOR_NAMES)
     t2_atomic_save(z,piece)
   }
   sc[[i]]<-z
 }
 out<-list(protocol="v3_real26_seedplan20",role=role,family=family,
           seed_index=as.integer(index),n=as.integer(n),replications=as.integer(R),
           scenarios=sc,grid=design$grid,bounds=design$bounds,
           params=params,target=target,component_names=ESTIMATOR_NAMES)
 t2_atomic_save(out,canonical)
 out
}
