t2_path <- function(shard,stage)file.path(t2_output_root(),shard,stage,'results',paste0(stage,'.rds'))
t2_seed <- function(shard,offset=0L) {
 a<-utf8ToInt(shard); as.integer((sum(a*seq_along(a))+offset)%%2000000000L+1L)
}
t2_families <- function()c('normal','lognormal','weibull','invgauss','exgaussian','exwald')
t2_params <- function(family) switch(family,
 normal=list(mean=0,sd=1),lognormal=list(meanlog=0,sdlog=.65),
 weibull=list(shape=2,scale=1),invgauss=list(mean=1,shape=3),
 exgaussian=list(mu=0,sigma=1,tau=1),exwald=list(mu=1,lambda=3,rate=1),stop('family'))
t2_make_scenarios <- function(mode,shard,n,replications,family='normal') {
 cfg<-ga_config; grid<-build_contamination_grid(cfg)
 if(mode=='smoke')grid<-grid[c(1L,2L,which(grid$rate==.1)[1],which(grid$rate==.2)[1]),]
 bands<-ifelse(grid$rate==0,'clean',ifelse(grid$rate<=.05,'low',ifelse(grid$rate<=.1,'intermediate','high')))
 seed<-t2_seed(shard,100L);set.seed(seed)
 params<-t2_params(family);target<-analytic_mean_from_params(family,params)
 sc<-vector('list',nrow(grid))
 for(j in seq_len(nrow(grid))) {
  s<-grid[j,];samples<-vector('list',replications)
  for(k in seq_len(replications)) {
   x<-generate_population(family,n,params)
   if(s$rate>0)x<-inject_outliers_realistic(x,contamination_rate=s$rate,outlier_scale_mad=s$scale,type=s$mechanism)
   samples[[k]]<-x
  }
  sc[[j]]<-list(T=component_matrix(samples),target=target,band=bands[j],eligible=rep(TRUE,26L),scenario_id=s$scenario_id,rate=s$rate,mechanism=s$mechanism)
 }
 list(scenarios=sc,grid=grid,seed=seed,family=family,n=n,replications=replications,target=target)
}
t2_models <- function(d) {
 mods<-reference_model_set()
 for(engine in names(d)) {
  result<-d[[engine]]; ix<-which.min(rowSums(sweep(result$objectives,2,pmax(colMeans(abs(result$objectives)),1e-12),'/')))
  mods[[length(mods)+1L]]<-new_frozen_model(engine,weights=result$weights[,ix],family=engine)
 }
 mods
}
t2_require <- function(shard,stage) {
 path<-t2_path(shard,stage)
 if(!file.exists(path))stop(paste('Required stage missing:',stage,'for',shard))
 t2_read_rds(path)
}
t2_inference <- function(T,models,target,stage,seed) {
 model_comparison_table(T,models,target,benchmark_id='mean',stage=stage,B=ga_config$bootstrap_B,seed=seed)
}
t2_precheck <- function(shard, stage, mode) {
 required <- switch(stage, montecarlo=c('datasets','mc_validation'),
   discovery=c('datasets','mc_validation','montecarlo'),
   heldout=c('discovery'),realworld=c('datasets','discovery'),
   stress=c('discovery'),aggregate=c('mc_validation','heldout','realworld','stress'), character())
 for (name in required) {
  previous <- t2_require(shard,name)
  if (!identical(previous$provenance$mode,mode)) stop(paste('Mode mismatch for dependency',name))
  if (name %in% c('datasets','mc_validation') && !identical(previous$status,'PASS'))
   stop(paste('Hard gate not passed:',name))
 }
 invisible(TRUE)
}
t2_run_datasets <- function(mode,shard) {
 manifest <- file.path('config','public_datasets.csv')
 if (!file.exists(manifest)) stop('Frozen public dataset manifest is missing')
 tab <- read.csv(manifest,stringsAsFactors=FALSE)
 if (!all(c('dataset_id','path','sha256','license') %in% names(tab))) stop('Incomplete dataset manifest')
 if (!nrow(tab)) stop('No datasets registered; cannot pass')
 if (mode=='full' && any(grepl('fixture',tab$license,ignore.case=TRUE))) stop('Fixtures are prohibited in full runs')
 if (any(!nzchar(tab$license))) stop('Dataset license not documented')
 if (any(!file.exists(tab$path))) stop('Dataset cache is incomplete')
 hashes <- unname(tools::md5sum(tab$path))
 if (anyNA(hashes)) stop('Cannot calculate dataset digests')
 if (requireNamespace('digest',quietly=TRUE)) {
  actual <- vapply(tab$path,digest::digest,character(1),algo='sha256',file=TRUE)
 } else {
  actual <- vapply(tab$path,function(f) {
   z<-suppressWarnings(system2('sha256sum',shQuote(f),stdout=TRUE))
   if(length(z)!=1L)stop('SHA256 unavailable');strsplit(z,' ')[[1]][1]
  },character(1))
 }
 if (any(tolower(actual)!=tolower(tab$sha256))) stop('Dataset integrity mismatch')
 list(status='PASS',manifest=tab,sha256=actual,fixture=identical(mode,'smoke'))
}
t2_run_mc_validation <- function(mode,shard) {
 d<-t2_require(shard,'datasets')
 if(!identical(d$status,'PASS'))stop('Datasets did not pass')
 seed<-t2_seed(shard,730L);set.seed(seed)
 n <- if(mode=='smoke') 1500L else 20000L
 x<-generate_population('normal',n,t2_params('normal'))
 l1 <- is.finite(mean(x)) && abs(mean(x)) < 5/sqrt(n) &&
       abs(sd(x)-1) < 5/sqrt(2*n)
 contaminated<-inject_outliers_realistic(x,contamination_rate=.2,outlier_scale_mad=9,type='upper_tail')
 l2 <- length(contaminated)==n && all(is.finite(contaminated)) &&
       abs(mean(contaminated)-mean(x))>1e-3
 m <- if(mode=='smoke') 120L else 1500L
 z<-replicate(m,{a<-rnorm(200);c(mean(a)^2,median(a)^2)})
 l3 <- mean(z[1,]) < mean(z[2,])
 l4 <- nrow(d$manifest)>=1L && all(file.exists(d$manifest$path))
 results<-data.frame(layer=c('L1','L2','L3','L4'),
                    status=ifelse(c(l1,l2,l3,l4),'PASS','FAIL'),
                    stringsAsFactors=FALSE)
 overall<-if(all(results$status=='PASS')) 'PASS' else 'FAIL'
 list(status=overall,layers=results,seed=seed,scientific_scope=if(mode=='smoke')
   'Interface smoke checks only; historical validation suite not certified' else
   'Simplified numerical checks only; historical four-layer certification pending',
   legacy_four_layer_certified=FALSE)
}
t2_run_discovery <- function(data,mode,shard,engine='all'){
 cfg<-ga_config
 if(mode=='smoke'){cfg$population<-8L;cfg$generations<-2L;cfg$patience<-2L;cfg$bootstrap_B<-100L}
 s<-data$scenarios
 engines<-list(nsga2=nsga_discover(s,cfg,t2_seed(shard,201)),de=de_discover(s,cfg,t2_seed(shard,202)),dirichlet=dirichlet_discover(s,cfg,t2_seed(shard,203),n_draws=cfg$population*(cfg$generations+1L)))
 if (engine != 'all') engines <- engines[engine]
 list(engines=engines,models=t2_models(engines),config=cfg,seed=t2_seed(shard,200))
}
t2_run_heldout <- function(discovery,mode,shard,family='normal') {
 cfg<-discovery$config; replications<-if(mode=='smoke')30L else cfg$evaluation_replicates
 n_values<-if(mode=='smoke')c(200L,1000L,3000L) else cfg$heldout_n
 by_n<-lapply(seq_along(n_values),function(i){
  n<-n_values[i];s<-t2_make_scenarios(mode,paste0(shard,'_heldout_',n),n,replications,family)$scenarios
  per_sc<-lapply(s,function(z){scores<-score_model_set(z$T,discovery$models,z$target);scores$scenario_id<-z$scenario_id;scores$sample_n<-n;scores})
  do.call(rbind,per_sc)
 })
 list(scores=do.call(rbind,by_n),models=discovery$models,stage='heldout',fresh_rng=TRUE)
}
t2_run_realworld <- function(discovery,mode,shard) {
 # A deterministic non-sensitive fixture verifies the external-data interface.
 # Full mode MUST receive reviewed public datasets, not synthetic fixtures.
 if(mode=='full') stop('Public real-world dataset manifest and fetch/verification adapter have not been configured')
 set.seed(t2_seed(shard,501));x<-rnorm(1100L)
 p<-realworld_prepare(x,sample_sizes=c(200L,1000L,3000L),R=30L,seed=t2_seed(shard,502))
 list(scores=realworld_compare_models(p,discovery$models,dataset_id='fixture'),fixture=TRUE)
}
t2_run_stress <- function(discovery,mode,shard,family='normal') {
 if(mode=='full')stop('Real-world stress manifest is not configured')
 x<-t2_make_scenarios('smoke',paste0(shard,'_stress'),200L,30L,family)
 result<-do.call(rbind,lapply(x$scenarios,function(s){z<-score_model_set(s$T,discovery$models,s$target);z$scenario_id<-s$scenario_id;z}))
 list(scores=result,stage='stress',fixture=TRUE)
}
t2_run_aggregate <- function(shard){
 d<-t2_require(shard,'discovery');h<-t2_require(shard,'heldout');r<-t2_require(shard,'realworld');s<-t2_require(shard,'stress')
 stopifnot(length(d$models)>4L,nrow(h$scores)>0L,nrow(r$scores)>0L,nrow(s$scores)>0L)
 lapply(list(heldout=h,realworld=r,stress=s),function(z)stopifnot(all(c('model','mse','q95')%in%names(z$scores))))
 list(stage='aggregate',results=list(heldout=h$scores,realworld=r$scores,stress=s$scores),fixture_realworld=isTRUE(r$fixture),fixture_stress=isTRUE(s$fixture))
}
run_t2_stage <- function(stage,shard,mode='smoke',family='normal',seed_index=0L,engine='all'){
 started<-Sys.time()
 base<-t2_stage_dirs(shard,stage)$base
 t2_precheck(shard,stage,mode)
 if(stage=='preflight'){
  scripts<-list.files('tests',pattern='\\.R$',full.names=TRUE)
  for(f in scripts){status<-system2('Rscript',f);if(status!=0L)stop(paste('Test failed:',f))}
  out<-list(status='pass',tests=basename(scripts))
 } else if(stage=='datasets'){
  out<-t2_run_datasets(mode,shard)
 } else if(stage=='mc_validation'){
  out<-t2_run_mc_validation(mode,shard)
  if(!identical(out$status,'PASS'))stop('Monte Carlo validation failed')
  if(mode=='full' && !isTRUE(out$legacy_four_layer_certified))stop('Full historical four-layer certification unavailable')
 } else if(stage=='montecarlo'){
  out<-t2_make_scenarios(mode,shard,if(mode=='smoke')30L else ga_config$train_n,if(mode=='smoke')30L else ga_config$evaluation_replicates,family)
 } else if(stage=='discovery'){
  out<-t2_run_discovery(t2_require(shard,'montecarlo'),mode,shard,engine)
 } else if(stage=='heldout'){
  out<-t2_run_heldout(t2_require(shard,'discovery'),mode,shard,family)
 } else if(stage=='realworld'){
  out<-t2_run_realworld(t2_require(shard,'discovery'),mode,shard)
 } else if(stage=='stress'){
  out<-t2_run_stress(t2_require(shard,'discovery'),mode,shard,family)
 } else if(stage=='aggregate'){
  out<-t2_run_aggregate(shard)
 }
 out$provenance<-list(shard=shard,stage=stage,mode=mode,family=family,seed_index=seed_index,engine=engine,
                      commit=Sys.getenv('GITHUB_SHA','local'),timestamp=as.character(Sys.time()))
 t2_emit_stage_artifacts(out,shard,stage,mode,family,t2_seed(shard,seed_index),started)
 invisible(out)
}
