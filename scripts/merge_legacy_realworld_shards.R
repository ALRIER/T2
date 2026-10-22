#!/usr/bin/env Rscript
root <- Sys.getenv('T2_CONFIRMATORY_ROOT', unset='artifacts/confirmatory')
out <- file.path(root,'legacy_realworld')
paths <- list.files(out, 'raw_manifest.csv$', recursive=TRUE, full.names=TRUE)
paths <- paths[normalizePath(paths, mustWork=FALSE) != normalizePath(file.path(out,'raw_manifest.csv'), mustWork=FALSE)]
if (!length(paths)) stop('No legacy real-world shard manifests found')
x <- do.call(rbind,lapply(paths,read.csv,stringsAsFactors=FALSE,check.names=FALSE))
if (anyDuplicated(x$dataset_id)) stop('Duplicate legacy real-world shard')
dir.create(file.path(out,'raw'),recursive=TRUE,showWarnings=FALSE)
for (id in x$dataset_id) {
  f <- list.files(out,paste0('^',id,'\\.rds$'),recursive=TRUE,full.names=TRUE)
  if (length(f)!=1L) stop('Expected exactly one raw shard for ',id)
  ok <- file.copy(f,file.path(out,'raw',basename(f)),overwrite=TRUE)
  if (!ok) stop('Could not assemble raw shard for ',id)
}
write.csv(x,file.path(out,'raw_manifest.csv'),row.names=FALSE)
writeLines('legacy_realworld_score COMPLETE',file.path(out,'score.status'))
cat('Merged',nrow(x),'legacy real-world shards\n')
