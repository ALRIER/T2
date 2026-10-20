args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], mustWork = TRUE) else normalizePath('.', mustWork = TRUE)
profiles <- read.csv(file.path(root, 'config/worker_profiles.csv'), stringsAsFactors = FALSE)
quotas <- c(
  github_actions = as.integer(Sys.getenv('T2_ACTIONS_SHARDS', '40')),
  physical_strong = as.integer(Sys.getenv('T2_STRONG_SHARDS', '128')),
  physical_local = as.integer(Sys.getenv('T2_LOCAL_SHARDS', '24'))
)
if (sum(quotas) != 192L || any(!names(quotas) %in% profiles$worker_id) || any(quotas < 0L))
  stop('Shard quotas must be non-negative and sum to 192')
families <- c('normal', 'lognormal', 'weibull', 'invgauss', 'exgaussian', 'exwald')
engines <- c('ga', 'nsga2', 'de', 'dirichlet')
seeds <- 0:7
grid <- expand.grid(family = families, engine = engines, seed = seeds,
                    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
family_weight <- c(normal=1, lognormal=1, weibull=1.05, invgauss=1.1,
                   exgaussian=1.2, exwald=1.25)
grid$estimated_weight <- unname(family_weight[grid$family])
grid <- grid[order(-grid$estimated_weight, grid$family, grid$engine, grid$seed), ]
load <- setNames(numeric(length(quotas)), names(quotas))
left <- quotas
assigned <- character(nrow(grid))
for (i in seq_len(nrow(grid))) {
  eligible <- names(left)[left > 0L]
  ratio <- load[eligible] / pmax(1, quotas[eligible])
  worker <- eligible[which.min(ratio)]
  assigned[i] <- worker
  load[worker] <- load[worker] + grid$estimated_weight[i]
  left[worker] <- left[worker] - 1L
}
grid$worker_id <- assigned
grid$shard <- sprintf('%s_%s_seed%02d', grid$family, grid$engine, grid$seed)
out <- grid[, c('worker_id','shard','family','engine','seed','estimated_weight')]
out <- out[order(out$worker_id, out$family, out$engine, out$seed), ]
dir.create(file.path(root, 'config'), recursive = TRUE, showWarnings = FALSE)
write.csv(out, file.path(root, 'config/shard_plan.csv'), row.names = FALSE, quote = FALSE)
cat('Wrote', nrow(out), 'shards to config/shard_plan.csv\n')
print(table(out$worker_id))
