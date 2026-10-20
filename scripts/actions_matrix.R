args <- commandArgs(trailingOnly = TRUE)
worker <- if (length(args)) args[1] else 'github_actions'
if (!identical(worker, 'github_actions')) stop('Production supports GitHub Actions only')
tab <- read.csv('config/shard_plan.csv', stringsAsFactors = FALSE)
families <- c('normal', 'lognormal', 'weibull', 'invgauss', 'exgaussian', 'exwald')
engines <- c('ga', 'nsga2', 'de', 'dirichlet')
expected <- expand.grid(family = families, engine = engines, seed = 0:7,
                        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
key <- function(x) paste(x$family, x$engine, x$seed, sep = ':')
if (nrow(tab) != nrow(expected) || anyNA(tab) ||
    any(tab$worker_id != 'github_actions') ||
    anyDuplicated(key(tab)) || !setequal(key(tab), key(expected)) ||
    any(tab$shard != sprintf('%s_%s_seed%02d', tab$family, tab$engine, tab$seed))) {
  stop('Invalid Actions shard plan: require exactly 192 distinct family/engine/seed shards')
}
rows <- vapply(seq_len(nrow(tab)), function(i) {
  sprintf('{"family":"%s","engine":"%s","seed":%d}',
          tab$family[i], tab$engine[i], as.integer(tab$seed[i]))
}, character(1))
cat(sprintf('{"include":[%s]}', paste(rows, collapse = ',')))
