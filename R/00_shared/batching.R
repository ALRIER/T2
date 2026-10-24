# Bounded-memory downstream processing; does not alter statistical definitions.
t2_batch_size <- function(n, env='T2_BATCH_SIZE', default=32L) {
  value <- suppressWarnings(as.integer(Sys.getenv(env, as.character(default))))
  if (length(value)!=1L || is.na(value) || value<1L) stop('Invalid batch size: ',env)
  min(value,as.integer(n))
}
t2_batch_indices <- function(n, size=t2_batch_size(n)) {
  if (!length(n) || is.na(n) || n<1L) return(list())
  split(seq_len(n), ceiling(seq_len(n)/size))
}
t2_score_models_batched <- function(T, models, target, eligible=rep(TRUE,26L)) {
  t2_validate_W(models)
  chunks <- t2_batch_indices(length(models), t2_batch_size(length(models),'T2_MODEL_BATCH_SIZE',32L))
  do.call(rbind,lapply(chunks,function(ix) score_model_set(T,models[ix],target,eligible)))
}
t2_score_scenarios_batched <- function(scenarios, models, sample_n=NULL) {
  if (!length(scenarios)) stop('No scenarios to score')
  chunks <- t2_batch_indices(length(scenarios),
                              t2_batch_size(length(scenarios),'T2_SCENARIO_BATCH_SIZE',8L))
  rows <- vector('list',length(chunks))
  for (k in seq_along(chunks)) {
    rows[[k]] <- do.call(rbind,lapply(scenarios[chunks[[k]]],function(sc) {
      z <- t2_score_models_batched(sc$T,models,sc$target)
      z$scenario_id <- sc$scenario_id
      if (!is.null(sample_n)) z$sample_n <- sample_n
      z
    }))
  }
  out <- do.call(rbind,rows)
  rownames(out) <- NULL
  t2_validate_scores(out)
  out
}
