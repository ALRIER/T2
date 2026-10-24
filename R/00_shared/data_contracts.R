# Versioned, read-only scientific data contracts for T2 downstream stages.
t2_contract_version <- function() 't2-data-v1'
t2_validate_T <- function(x, expected_family=NULL, expected_seed=NULL,
                          expected_reps=NULL, expected_scenarios=NULL) {
  if (!is.list(x) || !is.list(x$scenarios) || !length(x$scenarios))
    stop('T contract: missing scenarios')
  if (!is.null(expected_family) && !identical(x$family,expected_family))
    stop('T contract: family mismatch')
  if (!is.null(expected_seed) && !identical(as.integer(x$seed_index),as.integer(expected_seed)))
    stop('T contract: seed mismatch')
  if (!is.null(expected_scenarios) && length(x$scenarios)!=expected_scenarios)
    stop('T contract: scenario count mismatch')
  ids <- vapply(x$scenarios,function(s) as.integer(s$scenario_id),integer(1L))
  if (anyNA(ids) || anyDuplicated(ids) || any(ids<1L))
    stop('T contract: invalid scenario IDs')
  for (s in x$scenarios) {
    T <- s$T
    if (!is.matrix(T) || !is.numeric(T) || ncol(T)!=26L ||
        !nrow(T) || any(!is.finite(T)) ||
        (!is.null(expected_reps) && nrow(T)!=expected_reps) ||
        !is.numeric(s$target) || length(s$target)!=1L || !is.finite(s$target))
      stop('T contract: invalid 26-component estimator matrix or target')
    if (!is.null(colnames(T)) && !identical(as.character(colnames(T)),as.character(ESTIMATOR_NAMES)))
      stop('T contract: estimator component ordering mismatch')
  }
  invisible(TRUE)
}
t2_validate_W <- function(models) {
  if (!is.list(models) || !length(models)) stop('W contract: no models')
  ids <- vapply(models,function(m) as.character(m$id),character(1L))
  if (anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids))
    stop('W contract: missing or duplicate model IDs')
  for (m in models) {
    if (!is.null(m$weights)) {
      w <- m$weights
      if (!is.numeric(w) || length(w)!=26L || any(!is.finite(w)) ||
          any(w<0) || abs(sum(w)-1)>1e-8)
        stop('W contract: invalid simplex weight vector')
    } else if (is.null(m$component) || !m$component %in% ESTIMATOR_NAMES) {
      stop('W contract: invalid reference estimator')
    }
  }
  invisible(TRUE)
}
t2_validate_scores <- function(scores, required_ids=NULL) {
  if (!is.data.frame(scores) || !nrow(scores) ||
      !all(c('model','mse','q95') %in% names(scores)))
    stop('Score contract: missing model, mse or q95 columns')
  if (anyNA(scores$model) || any(!nzchar(as.character(scores$model))) ||
      !is.numeric(scores$mse) || !is.numeric(scores$q95) ||
      any(!is.finite(scores$mse)) || any(!is.finite(scores$q95)) ||
      any(scores$mse<0) || any(scores$q95<0))
    stop('Score contract: invalid values')
  if (!is.null(required_ids) && !all(required_ids %in% unique(as.character(scores$model))))
    stop('Score contract: missing expected models')
  invisible(TRUE)
}
t2_contract_stamp <- function(kind) data.frame(contract_version=t2_contract_version(),
                                                      contract_kind=kind,stringsAsFactors=FALSE)
