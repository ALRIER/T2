source('R/00_shared/load_all.R');t2_load('.');source('R/00_shared/pipeline.R')
shard<-'integration_smoke'
for(stage in c('datasets','mc_validation','montecarlo','discovery','heldout','realworld','stress','aggregate')){
 cat('STAGE',stage,'\n');run_t2_stage(stage,shard,'smoke','normal',0L)
}
a<-t2_read_rds(t2_path(shard,'aggregate'))
stopifnot(isTRUE(a$fixture_realworld),isTRUE(a$fixture_stress),nrow(a$results$heldout)>0)
cat('INTEGRATED SMOKE PASS (fixture data only)\n')
