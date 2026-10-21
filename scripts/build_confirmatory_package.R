#!/usr/bin/env Rscript

# Build the small, immutable input package used as a Zenodo recovery copy.
# Generated Monte Carlo errors are intentionally excluded: Actions regenerates
# them from the protocol and fresh seeds, while this package freezes the
# models, external inputs, code entry points, and checksums.

args <- commandArgs(trailingOnly = TRUE)
package_root <- if (length(args)) args[[1L]] else
  file.path('artifacts', 'confirmatory_release', 'T2_CONFIRMATORY_V1')
archive_path <- if (length(args) >= 2L) args[[2L]] else
  paste0(package_root, '.tar.gz')

repo_root <- normalizePath('.', winslash = '/', mustWork = TRUE)
package_root <- normalizePath(package_root, winslash = '/', mustWork = FALSE)
dir.create(package_root, recursive = TRUE, showWarnings = FALSE)

relative_files <- c(
  'R/00_shared/load_all.R',
  'R/06_confirmatory/confirmatory.R',
  'config/confirmatory_frozen_models.csv',
  'config/confirmatory_protocol.csv',
  'config/confirmatory_public_datasets.csv',
  'config/confirmatory_seed_roles.csv',
  'config/runtime_requirements.csv',
  'docs/confirmatory_protocol.md',
  'scripts/build_confirmatory_r_datasets.R',
  'scripts/run_confirmatory.R',
  'tests/test_confirmatory_contract.R',
  list.files('data/confirmatory', recursive = TRUE, full.names = FALSE)
)
relative_files <- sort(unique(relative_files))
relative_files <- relative_files[file.exists(file.path(repo_root, relative_files))]
if (!length(relative_files)) stop('No confirmatory package files found')

for (rel in relative_files) {
  target <- file.path(package_root, rel)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(file.path(repo_root, rel), target, overwrite = TRUE))
    stop('Failed to copy package file: ', rel)
}

git_commit <- tryCatch(system2('git', c('rev-parse', 'HEAD'), stdout = TRUE),
                       error = function(e) character())
provenance <- data.frame(
  package_id = 'T2_CONFIRMATORY_V1',
  source_git_commit = if (length(git_commit)) git_commit[[1L]] else 'uncommitted',
  source_r_version = as.character(getRversion()),
  generated_utc = format(Sys.time(), tz = 'UTC', usetz = TRUE),
  generated_mc_data = 'excluded; generated in Actions from fresh seeds 9:16',
  stringsAsFactors = FALSE)
write.csv(provenance, file.path(package_root, 'package_provenance.csv'),
          row.names = FALSE, quote = TRUE)

sha256 <- function(path) {
  if (requireNamespace('digest', quietly = TRUE))
    return(digest::digest(path, algo = 'sha256', file = TRUE))
  z <- suppressWarnings(system2('sha256sum', shQuote(path), stdout = TRUE))
  if (length(z) != 1L) stop('sha256sum unavailable for ', path)
  strsplit(z, '\\s+')[[1L]][1L]
}
all_files <- list.files(package_root, recursive = TRUE, full.names = TRUE)
all_files <- all_files[file.info(all_files)$isdir %in% FALSE]
manifest <- data.frame(
  path = substring(all_files, nchar(package_root) + 2L),
  bytes = as.numeric(file.info(all_files)$size),
  sha256 = vapply(all_files, sha256, character(1)),
  stringsAsFactors = FALSE)
manifest <- manifest[order(manifest$path), ]
write.csv(manifest, file.path(package_root, 'manifest_sha256.csv'),
          row.names = FALSE, quote = TRUE)

dir.create(dirname(archive_path), recursive = TRUE, showWarnings = FALSE)
if (file.exists(archive_path)) unlink(archive_path)
status <- system2('tar', c('-czf', archive_path, '-C', dirname(package_root),
                           basename(package_root)))
if (!identical(status, 0L)) stop('Unable to create package archive')
cat('Package:', package_root, '\n')
cat('Archive:', archive_path, '\n')
cat('Files:', nrow(manifest), 'bytes:', sum(manifest$bytes), '\n')
