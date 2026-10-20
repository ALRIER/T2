#!/usr/bin/env Rscript
# Reconstruct the exact primary registry selected by the original auditor.
# This is intentionally driven by the archived registry, not by a new catalog
# ranking, so the final battery remains comparable to the original report.

args <- commandArgs(trailingOnly=TRUE)
root <- if (length(args)) normalizePath(args[1], winslash='/', mustWork=TRUE) else getwd()
legacy <- file.path(root, 'R/04_real_datasets/legacy_sources')
source(file.path(legacy, 'realworld_external_battery_utils.R'))
exprs <- parse(file.path(legacy, '13_realworld_external_battery.R'))
for (expr in exprs) {
  if (grepl('source\\(file.path\\(eb_script_dir', paste(deparse(expr), collapse=''))) next
  eval(expr, envir=.GlobalEnv)
}

source_registry <- Sys.getenv(
  'T2_ORIGINAL_PRIMARY_REGISTRY',
  unset = file.path(root, '..', 'Genetic_Algorithms',
    'GA_Results/06_realworld_external_battery_40datasets/03_audit_ready/external_dataset_registry.csv')
)
if (!file.exists(source_registry)) stop('Original primary registry is unavailable')
reg <- read.csv(source_registry, stringsAsFactors=FALSE, check.names=FALSE)
reg <- reg[reg$selected_for_primary & reg$load_ok & reg$analysis_role == 'primary_dataset', , drop=FALSE]
if (nrow(reg) != 50L || sum(reg$source_group == 'market_returns') != 0L)
  stop('Original primary registry must contain 50 non-market tasks')

raw_dir <- file.path(root, 'data/realworld/raw/original_primary')
processed_dir <- file.path(root, 'data/realworld/processed/original_primary')
dir.create(raw_dir, recursive=TRUE, showWarnings=FALSE)
dir.create(processed_dir, recursive=TRUE, showWarnings=FALSE)
safe <- function(x) gsub('[^A-Za-z0-9_.-]+', '_', x)
sha <- function(path) {
  z <- system2('sha256sum', shQuote(path), stdout=TRUE)
  if (length(z) != 1L) stop('sha256sum unavailable')
  strsplit(z, '\\s+')[[1L]][1L]
}
make_spec <- function(r) eb_record(r$dataset_id[1], r$domain[1], r$source_url[1],
  r$loader[1], r$variable[1], r$transform[1], r$family_hint[1], r$subset_rule[1],
  notes=paste('Original registry primary task; archived source group', r$source_group[1]))

rows <- vector('list', nrow(reg))
for (i in seq_len(nrow(reg))) {
  r <- reg[i, , drop=FALSE]; sp <- make_spec(r)
  message(sprintf('[%d/%d] %s', i, nrow(reg), sp$id))
  loaded <- tryCatch(eb_load_one(sp, raw_dir), error=function(e)
    list(ok=FALSE, x=numeric(), path=NA_character_, variable=sp$variable,
         transform=sp$transform, error=conditionMessage(e), accessed_at=as.character(Sys.time())))
  if (!isTRUE(loaded$ok)) stop(sprintf('Original primary task failed to reacquire: %s (%s)',
                                       sp$id, loaded$error))
  x <- as.numeric(loaded$x); x <- x[is.finite(x)]
  path <- file.path(processed_dir, paste0(safe(sp$id), '.csv'))
  write.csv(data.frame(value=x), path, row.names=FALSE)
  raw <- normalizePath(loaded$path, winslash='/', mustWork=TRUE)
  rows[[i]] <- data.frame(
    dataset_id=sp$id, path=path, sha256=sha(path),
    license=if (grepl('^UCI_', sp$id)) 'UCI-public-dataset-license' else 'Rdatasets-source-package-license',
    variable=loaded$variable, transform=loaded$transform, source_url=sp$source_url,
    source_path=raw, source_sha256=sha(raw), domain=sp$domain, loader=sp$loader,
    family_hint=sp$family_hint, subset_rule=sp$subset_rule, stringsAsFactors=FALSE)
}
out <- do.call(rbind, rows)
for (nm in c('path','source_path')) out[[nm]] <- sub(paste0('^', normalizePath(root, winslash='/', mustWork=TRUE), '/'), '', out[[nm]])
write.csv(out, file.path(root, 'config/public_datasets.csv'), row.names=FALSE, na='')
write.csv(out, file.path(root, 'config/public_datasets_original_primary.csv'), row.names=FALSE, na='')
cat(sprintf('ORIGINAL PRIMARY BATTERY PASS: %d tasks\n', nrow(out)))
