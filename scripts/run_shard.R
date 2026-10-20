# Execute one independent family/seed shard in dependency order.
args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 3L) stop('Usage: Rscript scripts/run_shard.R MODE FAMILY SEED_INDEX [ENGINE] [SHARD]')
mode <- args[1]; family <- args[2]; seed_index <- as.integer(args[3])
engine <- if (length(args) > 3L) args[4] else 'all'
shard <- if (length(args) > 4L) args[5] else sprintf('%s_%s_seed%02d', family, engine, seed_index)
if (!mode %in% c('smoke','full')) stop('Invalid mode')
if (!engine %in% c('all','nsga2','de','dirichlet')) stop('Invalid engine')
source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
for (stage in c('datasets','mc_validation','montecarlo','discovery','heldout','realworld','stress','aggregate')) {
  cat('STAGE', stage, 'SHARD', shard, 'FAMILY', family, 'SEED', seed_index, '\n')
  if (identical(Sys.getenv('T2_RESUME', unset='0'), '1') && t2_stage_complete(shard, stage)) {
    cat('RESUME SKIP', stage, shard, '\n')
    next
  }
  run_t2_stage(stage, shard, mode, family, seed_index, engine)
}
cat('SHARD PASS', shard, '\n')
