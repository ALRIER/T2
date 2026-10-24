t2_require <- function(shard,stage) {
 path<-t2_dependency_path(shard,stage)
 if(!file.exists(path))stop(paste('Required stage missing:',stage,'for',shard))
 t2_read_rds(path)
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
