source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
a <- t2_run_integrated_mc_audits('smoke', 'historical_contract')
stopifnot(identical(a$status, 'PASS'),
          all(a$summary$status == 'PASS'),
          all(vapply(a$results, nrow, integer(1)) > 0L))
cat('HISTORICAL MC AUDIT CONTRACT PASS\n')
