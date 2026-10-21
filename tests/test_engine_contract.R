source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
x <- t2_make_scenarios('smoke', 'engine_contract', 30L, 4L, 'normal')
d <- t2_run_discovery(x, 'smoke', 'engine_contract', 'all')
stopifnot(identical(names(d$engines), c('ga', 'nsga2', 'de', 'dirichlet')),
          length(d$models) == 8L,
          all(vapply(d$engines, function(z) nrow(z$objectives) > 0L, logical(1))))
d_single <- d
d_single$engines <- d_single$engines['ga']
b_single <- t2_budget_parity_audit(d_single)
stopifnot(nrow(b_single) == 4L, all(b_single$budget_equal))
d_legacy <- d_single
d_legacy$budget_registry <- NULL
b_legacy <- t2_budget_parity_audit(d_legacy)
stopifnot(nrow(b_legacy) == 4L, all(b_legacy$budget_equal))
wf <- paste(readLines('.github/workflows/smoke.yml', warn = FALSE), collapse = '\n')
plan <- read.csv('config/shard_plan.csv', stringsAsFactors = FALSE)
stopifnot(identical(sort(unique(plan$engine)), c('de', 'dirichlet', 'ga', 'nsga2')),
          nrow(plan) == 192L,
          grepl('timeout-minutes: 360', wf), grepl('max-parallel: 32', wf),
          grepl('fromJSON\\(needs.plan.outputs.matrix\\)', wf))
cat('FOUR DISCOVERY ENGINE CONTRACT PASS\n')
