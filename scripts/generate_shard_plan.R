args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], mustWork = TRUE) else normalizePath('.', mustWork = TRUE)
families <- c('normal', 'lognormal', 'weibull', 'invgauss', 'exgaussian', 'exwald')
engines <- c('ga', 'nsga2', 'de', 'dirichlet')
seeds <- 0:7
grid <- expand.grid(family = families, engine = engines, seed = seeds,
                    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
family_weight <- c(normal=1, lognormal=1, weibull=1.05, invgauss=1.1,
                   exgaussian=1.2, exwald=1.25)
grid$estimated_weight <- unname(family_weight[grid$family])
grid$worker_id <- 'github_actions'
grid$shard <- sprintf('%s_%s_seed%02d', grid$family, grid$engine, grid$seed)
out <- grid[, c('worker_id','shard','family','engine','seed','estimated_weight')]
out <- out[order(out$family, out$engine, out$seed), ]
stopifnot(nrow(out) == 192L, !anyDuplicated(out$shard))
write.csv(out, file.path(root, 'config/shard_plan.csv'), row.names = FALSE, quote = FALSE)
cat('Wrote', nrow(out), 'GitHub Actions shards to config/shard_plan.csv\n')
