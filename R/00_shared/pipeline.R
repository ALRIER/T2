t2_path <- function(shard,stage)file.path(t2_output_root(),shard,stage,'results',paste0(stage,'.rds'))
t2_seed <- function(shard,offset=0L) {
 a<-utf8ToInt(shard); as.integer((sum(a*seq_along(a))+offset)%%2000000000L+1L)
}
t2_families <- function()c('normal','lognormal','weibull','invgauss','exgaussian','exwald')
t2_training_seed_indices <- function() as.integer(ga_config$training_seed_indices)
t2_heldout_seed_index <- function() as.integer(ga_config$heldout_seed_index)
t2_mc_seed <- function(family, seed_index) {
  t2_seed(sprintf('mc_%s_seed%02d', family, as.integer(seed_index)), 100L)
}
t2_mc_scenario_seed <- function(family, seed_index, scenario_id, shard=NULL) {
  key <- if (is.null(shard)) sprintf('mc_%s_seed%02d_scenario%04d', family,
                                     as.integer(seed_index), as.integer(scenario_id)) else
    sprintf('mc_%s_scenario%04d', shard, as.integer(scenario_id))
  t2_seed(key, 200L)
}
t2_mc_version <- function() 'v2_shared_base_crn'
t2_mc_workers <- function() {
  x<-as.integer(Sys.getenv('T2_MC_WORKERS',unset='1'))
  if(!is.finite(x)||x<1L)stop('T2_MC_WORKERS must be a positive integer')
  if(.Platform$OS.type!='unix')1L else x
}
t2_mc_root <- function() Sys.getenv('T2_CANONICAL_MC_ROOT', unset='artifacts/mc_canonical')
t2_shared_shard <- function() {
  x <- Sys.getenv('T2_SHARED_SHARD', unset='')
  if (!nzchar(x)) NULL else x
}
t2_dependency_path <- function(shard, stage) {
  local <- t2_path(shard, stage)
  if (file.exists(local)) return(local)
  shared <- t2_shared_shard()
  if (!is.null(shared)) {
    candidate <- t2_path(shared, stage)
    if (file.exists(candidate)) return(candidate)
  }
  local
}
t2_mc_path <- function(mode, family, seed_index, n, replications) {
  file.path(t2_mc_root(), t2_mc_version(), mode, family, sprintf('seed%02d', as.integer(seed_index)),
            sprintf('n%s_r%s.rds', as.integer(n), as.integer(replications)))
}
t2_params <- function(family) switch(family,
 normal=list(mean=0,sd=1),lognormal=list(meanlog=0,sdlog=.65),
 weibull=list(shape=2,scale=1),invgauss=list(mean=1,shape=3),
 exgaussian=list(mu=0,sigma=1,tau=1),exwald=list(mu=1,lambda=3,rate=1),stop('family'))
t2_make_scenarios <- function(mode,shard,n,replications,family='normal',seed_index=NULL) {
 cfg<-ga_config; grid<-build_contamination_grid(cfg)
 if(mode=='smoke')grid<-grid[c(1L,2L,which(grid$rate==.1)[1],which(grid$rate==.2)[1]),]
 bands<-ifelse(grid$rate==0,'clean',ifelse(grid$rate<=.05,'low',ifelse(grid$rate<=.1,'intermediate','high')))
  seed<-if(is.null(seed_index)) t2_seed(shard,100L) else t2_mc_seed(family, seed_index)
  params<-t2_params(family);target<-analytic_mean_from_params(family,params)
  set.seed(seed)
  base_samples<-vapply(seq_len(replications),function(k)generate_population(family,n,params),numeric(n))
  sc<-lapply(seq_len(nrow(grid)),function(j)
    t2_mc_generate_one(family,n,replications,grid[j,,drop=FALSE],target,base_samples,
                       if(is.null(seed_index))NULL else seed_index,shard))
 list(scenarios=sc,grid=grid,seed=seed,family=family,n=n,replications=replications,
      seed_index=if(is.null(seed_index)) NA_integer_ else as.integer(seed_index),
      role=if(is.null(seed_index)) 'legacy_local' else
        if(as.integer(seed_index)==t2_heldout_seed_index()) 'heldout' else 'training')
}
t2_mc_checkpoint_paths <- function(path) {
  list(root=paste0(path, '.parts'), progress=paste0(path, '.progress.rds'))
}
t2_mc_generate_one <- function(family, n, replications, row, target, base_samples,
                                seed_index=NULL, shard=NULL) {
  if (!is.matrix(base_samples) || nrow(base_samples)!=n || ncol(base_samples)!=replications)
    stop('Invalid canonical Monte Carlo base sample pool')
  if (row$rate > 0) set.seed(t2_mc_scenario_seed(family, seed_index, row$scenario_id, shard))
  samples<-vector('list',replications)
  for(k in seq_len(replications)) {
    x<-base_samples[,k]
    if(row$rate>0)x<-inject_outliers_realistic(x,contamination_rate=row$rate,
                                                outlier_scale_mad=row$scale,type=row$mechanism)
    samples[[k]]<-x
  }
  Tmat<-component_matrix(samples);eligible<-rep(TRUE,26L)
  list(T=Tmat,target=target,benchmark=precompute_benchmarks(Tmat,target,eligible),
       band=ifelse(row$rate==0,'clean',
       ifelse(row$rate<=.05,'low',ifelse(row$rate<=.1,'intermediate','high'))),
       eligible=eligible,scenario_id=row$scenario_id,rate=row$rate,mechanism=row$mechanism)
}
t2_canonical_mc <- function(mode, family, seed_index, n, replications) {
  if (!family %in% t2_families()) stop('Unknown Monte Carlo family')
  path <- t2_mc_path(mode, family, seed_index, n, replications)
  if (file.exists(path)) {
    out <- t2_read_rds(path)
    expected <- c(family=family, n=as.character(n), replications=as.character(replications),
                  seed_index=as.character(seed_index))
    got <- c(family=out$family, n=as.character(out$n), replications=as.character(out$replications),
             seed_index=as.character(out$seed_index))
    if (!identical(unname(got), unname(expected))) stop('Canonical Monte Carlo provenance mismatch')
    return(out)
  }
  cfg<-ga_config; grid<-build_contamination_grid(cfg)
  if(mode=='smoke')grid<-grid[c(1L,2L,which(grid$rate==.1)[1],which(grid$rate==.2)[1]),]
  cp<-t2_mc_checkpoint_paths(path)
  dir.create(cp$root, recursive=TRUE, showWarnings=FALSE)
  target<-analytic_mean_from_params(family,t2_params(family))
  base_path<-file.path(cp$root,'base_samples.rds')
  if (file.exists(base_path)) {
    base_samples<-t2_read_rds(base_path)
  } else {
    set.seed(t2_mc_seed(family,seed_index))
    params<-t2_params(family)
    base_samples<-vapply(seq_len(replications),function(k)generate_population(family,n,params),numeric(n))
    t2_atomic_save(base_samples,base_path)
  }
  progress<-NULL
  if(file.exists(cp$progress)) {
    progress<-t2_read_rds(cp$progress)
    expected<-list(mode=mode,family=family,seed_index=as.integer(seed_index),n=as.integer(n),
                   replications=as.integer(replications),grid=grid,
                   mc_version=t2_mc_version(),base_seed=t2_mc_seed(family,seed_index))
    if(!identical(progress[c('mode','family','seed_index','n','replications','grid',
                             'mc_version','base_seed')],expected))
      stop('Canonical Monte Carlo checkpoint provenance mismatch')
  } else {
    progress<-list(mode=mode,family=family,seed_index=as.integer(seed_index),n=as.integer(n),
                   replications=as.integer(replications),grid=grid,completed=integer(),
                   mc_version=t2_mc_version(),base_seed=t2_mc_seed(family,seed_index))
    t2_atomic_save(progress,cp$progress)
  }
  completed<-sort(unique(as.integer(progress$completed)))
  if (length(completed)) {
    part_paths<-file.path(cp$root,sprintf('scenario_%04d.rds',completed))
    if (any(!file.exists(part_paths))) stop('Canonical Monte Carlo checkpoint is incomplete')
  }
  todo<-setdiff(seq_len(nrow(grid)),completed)
  workers<-min(t2_mc_workers(),length(todo))
  batches<-if(!length(todo))list() else split(todo,ceiling(seq_along(todo)/workers))
  for(batch in batches) {
    parts<-if(workers>1L) parallel::mclapply(batch,function(j)
      t2_mc_generate_one(family,n,replications,grid[j,,drop=FALSE],target,base_samples,seed_index),
      mc.cores=length(batch),mc.preschedule=FALSE) else
      lapply(batch,function(j)t2_mc_generate_one(family,n,replications,grid[j,,drop=FALSE],
                                                  target,base_samples,seed_index))
    for(i in seq_along(batch)) {
      j<-batch[i];t2_atomic_save(parts[[i]],file.path(cp$root,sprintf('scenario_%04d.rds',j)))
      completed<-sort(c(completed,j));progress$completed<-completed
      t2_atomic_save(progress,cp$progress)
    }
  }
  sc<-lapply(seq_len(nrow(grid)),function(j)
    t2_read_rds(file.path(cp$root,sprintf('scenario_%04d.rds',j))))
  out <- list(scenarios=sc,grid=grid,seed=t2_mc_seed(family,seed_index),family=family,
              n=n,replications=replications,seed_index=as.integer(seed_index),
              role=if(as.integer(seed_index)==t2_heldout_seed_index()) 'heldout' else 'training',
              mc_version=t2_mc_version(),base_pool_reused=TRUE,
              scenario_seed_scheme='family_seed_scenario_id')
  out$canonical_id <- sprintf('%s_seed%02d_n%s_r%s', family, as.integer(seed_index), n, replications)
  out$generated_once <- TRUE
  t2_atomic_save(out, path)
  out
}
source('R/00_shared/data_contracts.R')
source('R/00_shared/batching.R')
# Downstream modules are loaded through this backward-compatible entrypoint.
source('R/00_shared/artifact_registry.R')
source('R/00_shared/frozen_registry.R')
source('R/00_shared/mc_loader.R')
source('R/02_discovery/discovery_runner.R')
source('R/03_heldout/validation_runner.R')
source('R/04_real_datasets/realworld_runner.R')
source('R/05_audits/inference_runner.R')

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
  n_mc <- if(mode=='smoke') 30L else ga_config$train_n
  r_mc <- if(mode=='smoke') 30L else ga_config$evaluation_replicates
  mc<-t2_canonical_mc(mode, family, seed_index, n_mc, r_mc)
  out<-list(stage='montecarlo',canonical_id=mc$canonical_id,family=family,
            seed_index=as.integer(seed_index),n=as.integer(n_mc),replications=as.integer(r_mc),
            mc_version=mc$mc_version,base_pool_reused=mc$base_pool_reused,
            scenario_seed_scheme=mc$scenario_seed_scheme,
            canonical_reference=data.frame(canonical_id=mc$canonical_id,version=mc$mc_version,
              family=family,seed_index=as.integer(seed_index),sample_n=as.integer(n_mc),
              replications=as.integer(r_mc),storage_root=t2_mc_root(),stringsAsFactors=FALSE))
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
