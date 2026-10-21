args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop('Usage: Rscript scripts/verify_precomputed_mc.R ROOT FAMILY')
root <- args[[1L]]
family <- args[[2L]]

source('R/00_shared/load_all.R')
t2_load('.')
source('R/00_shared/pipeline.R')

if (!family %in% t2_families()) stop('Invalid family: ', family)

expected <- rbind(
  data.frame(seed = 0:7, n = 1000L, replications = 500L),
  data.frame(seed = 8L, n = c(200L, 1000L, 3000L), replications = 500L),
  data.frame(seed = 8L, n = 1000L, replications = 250L)
)

check_block <- function(seed, n, replications) {
  path <- file.path(root, 'v2_shared_base_crn', 'full', family,
                    sprintf('seed%02d', seed),
                    sprintf('n%d_r%d.rds', n, replications))
  if (!file.exists(path)) stop('Missing precomputed block: ', path)
  x <- t2_read_rds(path)
  if (!is.list(x) || !is.list(x$scenarios) || length(x$scenarios) != 361L)
    stop('Invalid scenario container: ', path)
  if (!identical(as.character(x$family), family) ||
      !identical(as.integer(x$seed_index), as.integer(seed)) ||
      !identical(as.integer(x$n), as.integer(n)) ||
      !identical(as.integer(x$replications), as.integer(replications)) ||
      !identical(as.character(x$role), if (seed == 8L) 'heldout' else 'training') ||
      !identical(as.character(x$mc_version), 'v2_shared_base_crn'))
    stop('Provenance mismatch: ', path)
  ids <- vapply(x$scenarios, function(s) as.integer(s$scenario_id), integer(1L))
  if (!identical(ids, 1:361)) stop('Scenario IDs are not 1:361: ', path)
  for (s in x$scenarios) {
    if (!is.matrix(s$T) || nrow(s$T) != replications || ncol(s$T) != 26L ||
        !all(is.finite(s$T)) || !is.numeric(s$target) ||
        length(s$target) != 1L || !is.finite(s$target))
      stop('Invalid T/target payload: ', path)
  }
  invisible(path)
}

for (i in seq_len(nrow(expected)))
  check_block(expected$seed[[i]], expected$n[[i]], expected$replications[[i]])

cat('PRECOMPUTED MC PASS', family, nrow(expected), 'blocks\n')
