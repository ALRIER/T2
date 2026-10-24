# Optional immutable per-scenario scientific store. Canonical RDS remains authoritative.
t2_scenario_store <- function(canonical_path) paste0(canonical_path,'.scenarios')
t2_publish_scenario_store <- function(canonical_path, expected_family, expected_seed, selected=NULL) {
  if (!file.exists(canonical_path)) stop('Canonical RDS missing')
  root <- t2_scenario_store(canonical_path)
  manifest_path <- file.path(root,'scientific_manifest.csv')
  if (file.exists(manifest_path)) {
    t2_verify_scenario_store(canonical_path, expected_family, expected_seed, selected)
    return(invisible(manifest_path))
  }
  if (dir.exists(root) && length(list.files(root,all.files=TRUE,no..=TRUE)))
    stop('Partial scenario store exists; repair explicitly before publishing: ',root)
  canonical <- t2_read_rds(canonical_path)
  if (!identical(canonical$family,expected_family) ||
      !identical(as.integer(canonical$seed_index),as.integer(expected_seed)) ||
      !is.list(canonical$scenarios) || !length(canonical$scenarios))
    stop('Canonical provenance mismatch')
  dir.create(root,recursive=TRUE,showWarnings=FALSE)
  all_ids <- vapply(canonical$scenarios,function(s) as.integer(s$scenario_id),integer(1L))
  if (anyNA(all_ids) || anyDuplicated(all_ids)) stop('Invalid canonical scenario IDs')
  if (is.null(selected)) selected <- all_ids
  if (anyDuplicated(selected) || !all(selected %in% all_ids)) stop('Invalid selected scenario IDs')
  selected_indices <- match(selected,all_ids)
  rows <- vector('list',length(selected_indices))
  for (i in seq_along(selected_indices)) {
    s <- canonical$scenarios[[selected_indices[[i]]]]
    if (!is.matrix(s$T) || ncol(s$T)!=26L || !is.numeric(s$T) ||
        any(!is.finite(s$T)) || !is.finite(s$target))
      stop('Invalid canonical scenario')
    id <- as.integer(s$scenario_id)
    if (length(id)!=1L || is.na(id) || id<0L) stop('Invalid scenario ID')
    filename <- sprintf('scenario_%04d.rds',id)
    destination <- file.path(root,filename)
    if (file.exists(destination)) stop('Duplicate scenario ID')
    t2_atomic_save(s,destination)
    rows[[i]] <- data.frame(scenario_id=id,filename=filename,
      sha256=t2_sha256(destination),family=expected_family,
      seed_index=as.integer(expected_seed),replications=nrow(s$T),
      components=ncol(s$T),stringsAsFactors=FALSE)
  }
  m <- do.call(rbind,rows)
  if (anyDuplicated(m$scenario_id)) stop('Duplicate scenario IDs')
  t2_write_csv(m,manifest_path)
  invisible(manifest_path)
}
t2_verify_scenario_store <- function(canonical_path,family,seed,selected=NULL) {
  root <- t2_scenario_store(canonical_path)
  path <- file.path(root,'scientific_manifest.csv')
  if (!file.exists(path)) stop('Scenario manifest missing')
  m <- read.csv(path,stringsAsFactors=FALSE,check.names=FALSE)
  required <- c('scenario_id','filename','sha256','family','seed_index','replications','components')
  if (!all(required %in% names(m)) || !nrow(m) ||
      anyDuplicated(m$scenario_id) || anyDuplicated(m$filename) ||
      any(m$family!=family) || any(m$seed_index!=as.integer(seed)) ||
      any(m$components!=26L) || any(!grepl('^scenario_[0-9]{4}\\.rds$',m$filename)))
    stop('Invalid immutable scenario manifest')
  if (!is.null(selected)) {
    if (anyDuplicated(selected) || !all(selected %in% m$scenario_id))
      stop('Missing or duplicate requested scenarios')
    m <- m[match(selected,m$scenario_id),,drop=FALSE]
  }
  paths <- file.path(root,m$filename)
  if (any(!file.exists(paths))) stop('Scientific scenario files missing')
  digests <- vapply(paths,t2_sha256,character(1))
  if (!identical(tolower(unname(digests)),tolower(as.character(m$sha256))))
    stop('Immutable scenario checksum mismatch')
  m
}
t2_read_selected_scenarios <- function(canonical_path,family,seed,selected) {
  root <- t2_scenario_store(canonical_path)
  if (file.exists(file.path(root,'scientific_manifest.csv'))) {
    m <- t2_verify_scenario_store(canonical_path,family,seed,selected)
    return(lapply(m$filename,function(file) {
      s <- t2_read_rds(file.path(root,file))
      if (!is.matrix(s$T) || !is.numeric(s$T) || ncol(s$T)!=26L ||
          any(!is.finite(s$T))) stop('Corrupt scenario matrix')
      s
    }))
  }
  if (!file.exists(canonical_path)) stop('No canonical RDS or scenario store')
  x <- t2_read_rds(canonical_path)
  if (!identical(x$family,family) || !identical(as.integer(x$seed_index),as.integer(seed)))
    stop('Canonical fallback provenance mismatch')
  ids <- vapply(x$scenarios,function(s) as.integer(s$scenario_id),integer(1))
  if (anyDuplicated(ids) || !all(selected %in% ids)) stop('Canonical scenario IDs mismatch')
  x$scenarios[match(selected,ids)]
}
