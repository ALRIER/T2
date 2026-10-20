# Durable, stage-scoped output contract. The default root is inside the repo.
t2_output_root <- function() Sys.getenv('T2_OUTPUT_ROOT', unset='artifacts')
t2_max_file_bytes <- function() as.numeric(Sys.getenv('T2_MAX_FILE_MB', unset='25')) * 1024^2

t2_sha256 <- function(path) {
  out <- suppressWarnings(system2('sha256sum', shQuote(path), stdout=TRUE))
  if (length(out) != 1L) stop('sha256sum unavailable')
  strsplit(out, '\\s+')[[1]][1]
}

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
  if (file.info(tmp)$size <= t2_max_file_bytes()) {
    if (!file.rename(tmp, path)) stop('Failed atomic artifact write')
    return(invisible(path))
  }
  raw <- readBin(tmp, 'raw', n=file.info(tmp)$size)
  file.remove(tmp)
  part_size <- floor(t2_max_file_bytes())
  if (part_size < 1024L) stop('T2_MAX_FILE_MB is too small')
  parts <- character()
  for (start in seq.int(1L, length(raw), by=part_size)) {
    end <- min(length(raw), start + part_size - 1L)
    part <- sprintf('%s.part-%04d', path, length(parts) + 1L)
    writeBin(raw[start:end], part)
    parts <- c(parts, part)
  }
  index <- list(t2_chunked_rds=TRUE, parts=parts, bytes=length(raw),
                sha256=vapply(parts, t2_sha256, character(1)))
  saveRDS(index, path)
  invisible(path)
}

t2_read_rds <- function(path) {
  x <- readRDS(path)
  if (!is.list(x) || !isTRUE(x$t2_chunked_rds)) return(x)
  if (!length(x$parts) || !all(file.exists(x$parts))) stop('Chunked RDS is incomplete')
  if (!identical(unname(vapply(x$parts, t2_sha256, character(1))), unname(x$sha256)))
    stop('Chunked RDS checksum mismatch')
  raw <- do.call(c, lapply(x$parts, function(p) readBin(p, 'raw', n=file.info(p)$size)))
  con <- rawConnection(raw, 'rb'); on.exit(close(con), add=TRUE)
  readRDS(con)
}

t2_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive=TRUE, showWarnings=FALSE)
  x <- as.data.frame(x)
  tmp <- tempfile(pattern='t2-csv-', tmpdir=dirname(path))
  write.csv(x, tmp, row.names=FALSE, na='')
  if (file.info(tmp)$size <= t2_max_file_bytes()) {
    if (!file.rename(tmp, path)) stop('Failed atomic CSV write')
    return(invisible(path))
  }
  file.remove(tmp)
  if (!nrow(x)) stop('Cannot split an empty oversized CSV')
  chunks <- max(1L, ceiling(nrow(x) * 1.1))
  row_start <- 1L; part <- 1L
  while (row_start <= nrow(x)) {
    take <- min(chunks, nrow(x) - row_start + 1L)
    repeat {
      candidate <- tempfile(pattern='t2-csv-part-', tmpdir=dirname(path))
      write.csv(x[row_start:(row_start + take - 1L),,drop=FALSE], candidate, row.names=FALSE, na='')
      if (file.info(candidate)$size <= t2_max_file_bytes()) break
      file.remove(candidate)
      if (take == 1L) stop('A single CSV row exceeds T2_MAX_FILE_MB')
      take <- max(1L, floor(take * .7))
    }
    final <- sprintf('%s.part-%04d.csv', path, part)
    if (!file.rename(candidate, final)) stop('Failed atomic CSV part write')
    row_start <- row_start + take; part <- part + 1L
  }
  invisible(path)
}

t2_append_csv <- function(x, path) {
  dir.create(dirname(path), recursive=TRUE, showWarnings=FALSE)
  write.table(as.data.frame(x), path, sep=',', row.names=FALSE,
              col.names=!file.exists(path), append=file.exists(path), na='')
  invisible(path)
}

t2_stage_complete <- function(shard, stage) {
  d <- t2_stage_dirs(shard, stage)
  status <- file.path(d$checkpoints, paste0(stage, '.status'))
  result <- file.path(d$results, paste0(stage, '.rds'))
  trace <- file.path(d$trace, 'run_manifest.csv')
  if (!all(file.exists(status, result, trace))) return(FALSE)
  if (!any(grepl('COMPLETE$', readLines(status, warn=FALSE)))) return(FALSE)
  t2_validate_artifact_tree(d$base)
}

t2_validate_artifact_tree <- function(base) {
  files <- list.files(base, recursive=TRUE, full.names=TRUE)
  files <- files[file.info(files)$isdir %in% FALSE]
  if (any(file.info(files)$size > t2_max_file_bytes())) stop('Artifact exceeds T2_MAX_FILE_MB')
  invisible(TRUE)
}

t2_emit_stage_artifacts <- function(out, shard, stage, mode, family, seed, started) {
  d <- t2_stage_dirs(shard, stage)
  t2_atomic_save(out, file.path(d$results, paste0(stage, '.rds')))
  if (!is.null(out$manifest)) t2_write_csv(out$manifest, file.path(d$raw, 'dataset_manifest.csv'))
  if (!is.null(out$empirical_manifest)) t2_write_csv(out$empirical_manifest, file.path(d$raw, 'mc_empirical_manifest.csv'))
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
  t2_validate_artifact_tree(d$base)
  writeLines(paste(stage, shard, mode, family, seed, 'COMPLETE'),
             file.path(d$checkpoints, paste0(stage, '.status')))
  invisible(d)
}
