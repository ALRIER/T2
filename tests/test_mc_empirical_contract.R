source('R/00_shared/load_all.R'); t2_load('.')
m <- t2_mc_manifest()
stopifnot(nrow(m) == 5L,
          identical(m$dataset_id, c('DS1_Wine_Alcohol','DS2_ForestFires_logArea',
                                    'DS3_GBSG2_Survival','DS4_RT_LexicalDecision',
                                    'DS5_SPY_LogReturns')),
          all(m$purpose == 'empirical_shape_anchor'))
s <- t2_run_mc_empirical_anchoring('smoke', 'mc_contract')
stopifnot(identical(s$status, 'SKIPPED'), nrow(s$manifest) == 5L)
cat('MC EMPIRICAL LAYER CONTRACT PASS\n')
