# Durable, stage-scoped output contract. The default root is inside the repo.
t2_output_root <- function() Sys.getenv('T2_OUTPUT_ROOT', unset='artifacts')

t2_stage_dirs <- function(shard, stage) {
  base <- file.path(t2_output_root(), shard, stage)
  dirs <- file.path(base, c('raw', 'checkpoints', 'results', 'trace'))
  invisible(lapply(dirs, dir.create, recursive=TRUE, showWarnings=FALSE))
  list(base=base, raw=dirs[1], checkpoints=dirs[2], results=dirs[3], trace=dirs[4])
}

t2_atomic_save <- function(x, path) {
  dir.create(dirname(path), recursive=TRUE, showWarnings=FALSE)
  tmp <- paste0(path, '.', Sys.getpid(), '.tmp')
  saveRDS(x, tmp)
  if (!file.rename(tmp, path)) stop('Failed atomic artifact write')
  invisible(path)
}

t2_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive=TRUE, showWarnings=FALSE)
  write.csv(as.data.frame(x), path, row.names=FALSE, na='')
  invisible(path)
}

t2_append_csv <- function(x, path) {
  dir.create(dirname(path), recursive=TRUE, showWarnings=FALSE)
  write.table(as.data.frame(x), path, sep=',', row.names=FALSE,
              col.names=!file.exists(path), append=file.exists(path), na='')
  invisible(path)
}

t2_emit_stage_artifacts <- function(out, shard, stage, mode, family, seed, started) {
  d <- t2_stage_dirs(shard, stage)
  t2_atomic_save(out, file.path(d$results, paste0(stage, '.rds')))
  if (!is.null(out$manifest)) t2_write_csv(out$manifest, file.path(d$raw, 'dataset_manifest.csv'))
  if (!is.null(out$layers)) t2_write_csv(out$layers, file.path(d$results, 'validation_layers.csv'))
  if (!is.null(out$grid)) t2_write_csv(out$grid, file.path(d$raw, 'scenario_grid.csv'))
  if (!is.null(out$scenarios)) for (i in seq_along(out$scenarios))
    t2_write_csv(out$scenarios[[i]]$T, file.path(d$raw, sprintf('scenario_%04d_matrix.csv', i)))
  if (!is.null(out$engines)) for (nm in names(out$engines)) {
    z <- out$engines[[nm]]
    t2_write_csv(z$objectives, file.path(d$results, paste0('engine_', nm, '_objectives.csv')))
    t2_write_csv(z$weights, file.path(d$results, paste0('engine_', nm, '_weights.csv')))
  }
  for (nm in c('scores', 'condition_rows', 'dataset_level'))
    if (!is.null(out[[nm]])) {
      t2_write_csv(out[[nm]], file.path(d$results, paste0(nm, '.csv')))
      if (identical(nm, 'scores')) t2_write_csv(out[[nm]], file.path(d$raw, 'raw_scores.csv'))
    }
  if (!is.null(out$results)) for (nm in names(out$results))
    if (is.data.frame(out$results[[nm]])) t2_write_csv(out$results[[nm]], file.path(d$results, paste0(nm, '.csv')))
  finished <- Sys.time()
  trace <- data.frame(shard=shard, stage=stage, mode=mode, family=family,
    seed=as.integer(seed), status='PASS',
    started_utc=format(started, tz='UTC', usetz=TRUE),
    finished_utc=format(finished, tz='UTC', usetz=TRUE),
    commit=Sys.getenv('GITHUB_SHA', unset='local'), stringsAsFactors=FALSE)
  t2_append_csv(trace, file.path(d$trace, 'events.csv'))
  t2_write_csv(trace, file.path(d$trace, 'run_manifest.csv'))
  writeLines(paste(stage, shard, mode, family, seed, 'COMPLETE'),
             file.path(d$checkpoints, paste0(stage, '.status')))
  invisible(d)
}
