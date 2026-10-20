source('R/00_shared/load_all.R'); t2_load('.')
root <- tempfile('t2-artifacts-'); Sys.setenv(T2_OUTPUT_ROOT=root)
source('R/00_shared/pipeline.R')
run_t2_stage('datasets', 'contract_seed00', 'smoke', 'normal', 0L)
d <- t2_stage_dirs('contract_seed00', 'datasets')
stopifnot(file.exists(file.path(d$results, 'datasets.rds')),
          file.exists(file.path(d$raw, 'dataset_manifest.csv')),
          file.exists(file.path(d$trace, 'events.csv')),
          file.exists(file.path(d$checkpoints, 'datasets.status')))
unlink(root, recursive=TRUE)
cat('ARTIFACT CONTRACT PASS\n')
