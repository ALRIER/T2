# Immutable scientific provenance for downstream T and W.
# Cell IDs are computed from immutable block ID, scenario ID, replication,
# component ID; materializing millions of IDs is optional.
t2_trace_hash <- function(x) {
  f <- tempfile(pattern='t2-provenance-')
  on.exit(unlink(f), add=TRUE)
  saveRDS(x, f, version=3, compress=FALSE)
  t2_sha256(f)
}
t2_trace_ids <- function(family, seed, n, reps, scenario_id, component_names) {
  if (length(component_names)!=26L || anyDuplicated(component_names))
    stop('Invalid component registry')
  block <- sprintf('T-%s-s%02d-n%d-r%d', family, as.integer(seed),
                   as.integer(n), as.integer(reps))
  scenario <- sprintf('%s-sc%04d', block, as.integer(scenario_id))
  list(block=block, scenario=scenario,
       columns=paste0(scenario, '-c', sprintf('%02d', seq_along(component_names))),
       cell_id=function(replication, component_index)
         sprintf('%s-r%04d-c%02d', scenario, as.integer(replication),
                 as.integer(component_index)))
}
t2_trace_t <- function(x, family, seed, n, reps, root) {
  dir.create(root, recursive=TRUE, showWarnings=FALSE)
  rows <- lapply(x$scenarios, function(s) {
    T <- s$T
    if (!is.matrix(T) || !is.numeric(T) ||
        !identical(dim(T), c(as.integer(reps), 26L)) ||
        any(!is.finite(T)) || length(s$target)!=1L || !is.finite(s$target))
      stop('Invalid canonical T')
    ids <- t2_trace_ids(family,seed,n,reps,s$scenario_id,colnames(T))
    data.frame(matrix_id=ids$block, scenario_id=ids$scenario,
               scenario_number=as.integer(s$scenario_id),
               t_sha256=t2_trace_hash(T),
               target_sha256=t2_trace_hash(s$target),
               replication_count=nrow(T),component_count=ncol(T),
               stringsAsFactors=FALSE)
  })
  z <- do.call(rbind,rows)
  if (anyDuplicated(z$scenario_id)) stop('Duplicate T scenario IDs')
  path <- file.path(root,'t_scenario_trace.csv')
  if (file.exists(path)) {
    previous <- read.csv(path,stringsAsFactors=FALSE,check.names=FALSE)
    if (!identical(previous,z)) stop('Existing T trace differs: immutable contract violation')
  } else t2_write_csv(z,path)
  z
}
t2_trace_w <- function(manifest, root) {
  required <- c('model_id','family','engine','training_seed','weights_path','weights_sha256')
  if (!all(required %in% names(manifest))) stop('Invalid W model manifest')
  if (anyDuplicated(manifest$model_id)) stop('Duplicate candidate IDs')
  if (any(!file.exists(manifest$weights_path))) stop('Missing frozen W file')
  actual <- vapply(manifest$weights_path,t2_sha256,character(1))
  if (!identical(tolower(actual),tolower(as.character(manifest$weights_sha256))))
    stop('Frozen W hash mismatch')
  dir.create(root,recursive=TRUE,showWarnings=FALSE)
  z <- manifest[,required,drop=FALSE]
  z$weight_vector_id <- paste0('W-',z$model_id)
  z$verified_sha256 <- actual
  path <- file.path(root,'w_candidate_trace.csv')
  if (file.exists(path)) {
    old <- read.csv(path,stringsAsFactors=FALSE,check.names=FALSE)
    if (!identical(old,z)) stop('Existing W trace differs: immutable contract violation')
  } else t2_write_csv(z,path)
  z
}
