args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[1] else 'full'
if (!mode %in% c('smoke', 'full')) stop('Usage: Rscript scripts/build_realworld_bundle.R smoke|full')
source('R/00_shared/load_all.R'); t2_load('.')
t2_check_runtime('.', strict = TRUE)
source('R/00_shared/pipeline.R')
tab <- t2_realworld_validate_manifest(t2_realworld_manifest(), mode)
sample_sizes <- if (mode == 'smoke') c(200L, 1000L, 3000L) else {
  as.integer(strsplit(Sys.getenv('T2_REALWORLD_SAMPLE_SIZES', '200,1000,3000'), ',', fixed=TRUE)[[1]])
}
reps <- as.integer(Sys.getenv('T2_REALWORLD_REPS', if (mode == 'smoke') '30' else '500'))
if (!length(sample_sizes) || !is.finite(reps) || reps < 3L) stop('Invalid real-world bundle configuration')
datasets <- lapply(seq_len(nrow(tab)), function(i) t2_realworld_load_vector(tab[i,,drop=FALSE]))
ids <- vapply(datasets, `[[`, character(1), 'dataset_id')
prepared <- lapply(seq_along(datasets), function(i) {
  realworld_prepare(datasets[[i]]$x, sample_sizes=sample_sizes, R=reps,
                    seed=t2_seed('realworld_canonical_bundle', 502L+i))
})
names(prepared) <- ids
bundle <- list(bundle_id='realworld_prepared_v1', mode=mode, manifest_sha256=as.character(tab$sha256),
               dataset_ids=ids, sample_sizes=sample_sizes, reps=reps,
               prepared=prepared, seed_scheme='realworld_canonical_bundle')
path <- Sys.getenv('T2_REALWORLD_BUNDLE', unset='artifacts/shared/realworld_bundle.rds')
t2_atomic_save(bundle, path)
cat('REALWORLD BUNDLE PASS', path, length(prepared), 'datasets\n')
