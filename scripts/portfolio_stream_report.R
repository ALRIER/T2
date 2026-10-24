# Two-pass global BH correction: retain only p-value vectors in memory.
# First pass collects the complete multiplicity family; second pass publishes
# per-shard classified rows without materializing all taxonomies at once.
pg_global_fdr_stream <- function(paths, destination) {
  if (!length(paths)) stop('Empty global FDR family')
  paths <- sort(paths)
  p_mse <- vector('list',length(paths))
  p_q95 <- vector('list',length(paths))
  counts <- integer(length(paths))
  for (i in seq_along(paths)) {
    z <- read.csv(paths[[i]],stringsAsFactors=FALSE,check.names=FALSE)
    needed <- c('mse_p_value','q95_p_value','mse_difference',
                'q95_difference','mse_ci_high','q95_ci_high')
    if (!all(needed %in% names(z)) || !nrow(z)) stop('Incomplete inference shard: ',paths[[i]])
    p_mse[[i]] <- z$mse_p_value
    p_q95[[i]] <- z$q95_p_value
    counts[[i]] <- nrow(z)
  }
  adjusted_mse <- p.adjust(unlist(p_mse,use.names=FALSE),method='BH')
  adjusted_q95 <- p.adjust(unlist(p_q95,use.names=FALSE),method='BH')
  rm(p_mse,p_q95)
  dir.create(dirname(destination),recursive=TRUE,showWarnings=FALSE)
  staged <- paste0(destination,'.inprogress')
  if (file.exists(staged)) unlink(staged)
  published <- FALSE
  on.exit(if (!published && file.exists(staged)) unlink(staged),add=TRUE)
  cursor <- 0L
  for (i in seq_along(paths)) {
    z <- read.csv(paths[[i]],stringsAsFactors=FALSE,check.names=FALSE)
    ix <- seq.int(cursor+1L,cursor+counts[[i]])
    z$mse_q_value <- adjusted_mse[ix]
    z$q95_q_value <- adjusted_q95[ix]
    z$mse_supported <- z$mse_difference<0 & z$mse_ci_high<0 & z$mse_q_value<=.05
    z$q95_supported <- z$q95_difference<0 & z$q95_ci_high<0 & z$q95_q_value<=.05
    z$evidence_taxonomy <- ifelse(z$mse_supported & z$q95_supported,'mse_and_q95',
                          ifelse(z$mse_supported,'mse_only',
                          ifelse(z$q95_supported,'q95_only','neither_metric')))
    write.table(z,staged,sep=',',row.names=FALSE,quote=TRUE,na='',
                col.names=!file.exists(staged),append=file.exists(staged))
    cursor <- cursor+counts[[i]]
  }
  if (!file.rename(staged,destination)) stop('Failed atomic global FDR publication')
  published <- TRUE
  invisible(sum(counts))
}
