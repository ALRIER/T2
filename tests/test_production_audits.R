source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
set.seed(17)
T <- matrix(rnorm(120L * 26L), 120L, 26L); colnames(T) <- ESTIMATOR_NAMES
S <- lapply(c('clean','low','intermediate','high'), function(b)
  list(T=T, target=0, band=b, eligible=rep(TRUE,26L)))
cfg <- ga_config; cfg$population <- 8L; cfg$generations <- 2L; cfg$patience <- 2L
d <- t2_run_discovery(list(scenarios=S), 'smoke', 'audit_contract')
b <- t2_budget_parity_audit(d)
h <- t2_heldout_independence_audit(d, 'smoke', 'audit_contract', 'normal', c(200L,1000L,3000L))
stopifnot(nrow(b) == 4L, all(b$budget_equal), h$status == 'PASS',
          h$training_partition == 'discovery_training_only',
          h$heldout_partition == 'fresh_rng')
old_n <- Sys.getenv('T2_STRESS_SAMPLE_N', unset=NA_character_)
old_r <- Sys.getenv('T2_STRESS_REPS', unset=NA_character_)
Sys.setenv(T2_STRESS_SAMPLE_N='50', T2_STRESS_REPS='6')
on.exit({
  if (is.na(old_n)) Sys.unsetenv('T2_STRESS_SAMPLE_N') else Sys.setenv(T2_STRESS_SAMPLE_N=old_n)
  if (is.na(old_r)) Sys.unsetenv('T2_STRESS_REPS') else Sys.setenv(T2_STRESS_REPS=old_r)
}, add=TRUE)
st <- t2_run_stress(d, 'full', 'audit_contract', 'normal')
stopifnot(!isTRUE(st$fixture), nrow(st$scores) > 0L,
          st$stress_config$replications == 6L)
cat('PRODUCTION AUDIT CONTRACT PASS\n')
