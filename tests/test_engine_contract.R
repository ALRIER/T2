source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
x <- t2_make_scenarios('smoke', 'engine_contract', 30L, 4L, 'normal')
d <- t2_run_discovery(x, 'smoke', 'engine_contract', 'all')
stopifnot(identical(names(d$engines), c('ga', 'nsga2', 'de', 'dirichlet')),
          length(d$models) == 8L,
          all(vapply(d$engines, function(z) nrow(z$objectives) > 0L, logical(1))))
cat('FOUR DISCOVERY ENGINE CONTRACT PASS\n')
