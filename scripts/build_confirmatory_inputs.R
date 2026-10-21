#!/usr/bin/env Rscript

# Build the immutable frozen-model package used by the confirmatory layer.
# The source must be a completed, reconstructed full archive. This script
# never selects a winner from held-out or real-world results: it reproduces
# the discovery-stage frozen-model rule from t2_models().

args <- commandArgs(trailingOnly = TRUE)
source_root <- if (length(args) >= 1L) args[[1L]] else
  file.path('artifacts', 'actions_archive', '39667957808_unified_reconstructed')
out_root <- if (length(args) >= 2L) args[[2L]] else
  file.path('data', 'confirmatory', 'frozen_models')
manifest_path <- if (length(args) >= 3L) args[[3L]] else
  file.path('config', 'confirmatory_frozen_models.csv')

if (!dir.exists(source_root)) stop('Frozen full archive is missing: ', source_root)
source('R/00_shared/load_all.R')
t2_load('.')
dirs <- list.dirs(source_root, full.names = TRUE, recursive = FALSE)
dirs <- dirs[grepl('^full-[^-]+-(ga|nsga2|de|dirichlet)-[0-9]+-final$', basename(dirs))]
if (length(dirs) != 192L)
  stop('Expected 192 reconstructed final shards; found ', length(dirs))

sha256 <- function(path) {
  z <- suppressWarnings(system2('sha256sum', shQuote(path), stdout = TRUE))
  if (length(z) != 1L) stop('sha256sum unavailable for ', path)
  strsplit(z, '\\s+')[[1L]][1L]
}

parse_shard <- function(path) {
  z <- strsplit(sub('^full-', '', basename(path)), '-', fixed = TRUE)[[1L]]
  if (length(z) != 4L || z[[4L]] != 'final') stop('Invalid shard: ', path)
  list(family = z[[1L]], engine = z[[2L]], seed = as.integer(z[[3L]]))
}

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
rows <- list()
for (path in sort(dirs)) {
  meta <- parse_shard(path)
  if (!meta$seed %in% 0:7) stop('Unexpected training seed: ', path)
  op <- file.path(path, 'discovery', 'results',
                  paste0('engine_', meta$engine, '_objectives.csv'))
  wp <- file.path(path, 'discovery', 'results',
                  paste0('engine_', meta$engine, '_weights.csv'))
  if (!file.exists(op) || !file.exists(wp)) stop('Missing discovery outputs: ', path)
  objectives <- read.csv(op, check.names = FALSE, stringsAsFactors = FALSE)
  weights <- read.csv(wp, check.names = FALSE, stringsAsFactors = FALSE)
  if (nrow(weights) != 26L)
    stop('Expected 26 components in ', path)
  if (!ncol(weights) || !ncol(objectives)) stop('Empty optimizer outputs: ', path)
  # Archived stage artifacts contain the already selected discovery vector.
  # Older archives may contain a matrix of candidates; support both layouts.
  if (ncol(weights) == 1L) {
    selected <- as.numeric(weights[, 1L])
  } else {
    if (nrow(objectives) != ncol(weights))
      stop('Candidate objective/weight dimensions disagree: ', path)
    scale <- pmax(colMeans(abs(objectives)), 1e-12)
    ix <- which.min(colSums(sweep(as.matrix(objectives), 2L, scale, '/')))
    selected <- as.numeric(weights[, ix])
  }
  selected[!is.finite(selected)] <- 0
  if (length(selected) != 26L || any(selected < 0) || sum(selected) <= 0)
    stop('Invalid frozen weight vector: ', path)
  selected <- selected / sum(selected)
  model_id <- sprintf('%s_%s_train%02d', meta$family, meta$engine, meta$seed)
  file_name <- paste0(model_id, '.csv')
  file_path <- file.path(out_root, file_name)
  write.csv(data.frame(component = ESTIMATOR_NAMES,
                       weight = selected), file_path, row.names = FALSE, quote = TRUE)
  rows[[length(rows) + 1L]] <- data.frame(
    model_id = model_id, family = meta$family, engine = meta$engine,
    training_seed = meta$seed,
    weights_path = file.path('data', 'confirmatory', 'frozen_models', file_name),
    weights_sha256 = sha256(file_path),
    source_shard = basename(path), source_objectives = sha256(op),
    source_weights = sha256(wp), selection_rule = 't2_models_v1',
    stringsAsFactors = FALSE)
}
manifest <- do.call(rbind, rows)
manifest <- manifest[order(manifest$family, manifest$engine, manifest$training_seed), ]
if (nrow(manifest) != 192L || anyDuplicated(manifest$model_id))
  stop('Frozen model manifest is not 192 unique rows')
dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
write.csv(manifest, manifest_path, row.names = FALSE, quote = TRUE)
cat('Wrote', nrow(manifest), 'frozen models to', out_root, '\n')
cat('Manifest:', manifest_path, '\n')
