source('R/00_shared/load_all.R');t1_load('.');source('R/00_shared/pipeline.R')
shard<-'integration_smoke'
for(stage in c('datasets','mc_validation','montecarlo','discovery','heldout','realworld','stress','aggregate')){
 cat('STAGE',stage,'\n');run_t1_stage(stage,shard,'smoke')
}
a<-readRDS(t1_path(shard,'aggregate'))
stopifnot(isTRUE(a$fixture_realworld),isTRUE(a$fixture_stress),nrow(a$results$heldout)>0)
cat('INTEGRATED SMOKE PASS (fixture data only)\n')
