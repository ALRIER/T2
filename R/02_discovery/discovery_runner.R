t2_run_discovery <- function(data,mode,shard,engine='all'){
 data <- t2_load_mc_for_discovery(data, mode)
 t2_validate_T(data)
 cfg<-ga_config
 if(mode=='smoke'){cfg$population<-8L;cfg$generations<-2L;cfg$patience<-2L;cfg$bootstrap_B<-100L}
 s<-data$scenarios
 dispatch <- list(
   ga=function() ga_discover(s,cfg,t2_seed(shard,201),shard=shard),
   nsga2=function() nsga_discover(s,cfg,t2_seed(shard,202),shard=shard),
   de=function() de_discover(s,cfg,t2_seed(shard,203),shard=shard),
   dirichlet=function() dirichlet_discover(s,cfg,t2_seed(shard,204),n_draws=cfg$population*(cfg$generations+1L),shard=shard)
 )
 selected <- if (engine == 'all') names(dispatch) else engine
 if (!all(selected %in% names(dispatch))) stop('Unknown discovery engine')
 engines <- setNames(lapply(selected, function(name) dispatch[[name]]()), selected)
 list(engines=engines,models=t2_models(engines),config=cfg,
      budget_registry=t2_discovery_budget_registry(cfg),seed=t2_seed(shard,200),
      training_seed_index=if (length(data$seed_index)) as.integer(data$seed_index) else 0L,
      mc_canonical_id=if(is.null(data$canonical_id)) NA_character_ else data$canonical_id)
}
