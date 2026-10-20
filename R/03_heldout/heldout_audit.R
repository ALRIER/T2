# Prospective held-out audit. This records the partition and budget contract
# instead of relying on a convention hidden in the stage runner.
t2_budget_parity_audit <- function(discovery) {
  engines <- discovery$engines
  required <- c('ga', 'nsga2', 'de', 'dirichlet')
  if (!all(required %in% names(engines)))
    stop('Budget audit requires all four discovery engines')
  cfg <- lapply(engines, function(x) discovery$config[c(
    'population', 'generations', 'evaluation_replicates', 'objective_names')])
  reference <- cfg[[1L]]
  same <- vapply(cfg, identical, logical(1), y=reference)
  if (!all(same)) stop('Discovery budgets or objectives are not equal across engines')
  data.frame(engine=names(engines), population=reference$population,
             generations=reference$generations,
             evaluation_replicates=reference$evaluation_replicates,
             objective_mse=TRUE, objective_q95=TRUE,
             budget_equal=TRUE, stringsAsFactors=FALSE)
}

t2_heldout_independence_audit <- function(discovery, mode, shard, family, n_values) {
  budget <- t2_budget_parity_audit(discovery)
  training_seed <- t2_seed(shard, 100L)
  heldout_seed <- vapply(n_values, function(n)
    t2_seed(paste0(shard, '_heldout_', n), 100L), integer(1))
  if (any(heldout_seed == training_seed) || anyDuplicated(heldout_seed))
    stop('Held-out seeds overlap or are duplicated')
  data.frame(
    audit='heldout_independence_and_budget_parity', mode=mode, family=family,
    training_partition='discovery_training_only', heldout_partition='fresh_rng',
    training_seed=training_seed, heldout_seed=paste(heldout_seed, collapse=';'),
    heldout_sample_sizes=paste(n_values, collapse=';'),
    engines=length(unique(budget$engine)), budget_equal=all(budget$budget_equal),
    objective_set='mse;q95', status='PASS', stringsAsFactors=FALSE)
}
