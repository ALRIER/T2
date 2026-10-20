args <- commandArgs(trailingOnly = TRUE)
worker <- if (length(args)) args[1] else 'github_actions'
tab <- read.csv('config/shard_plan.csv', stringsAsFactors = FALSE)
tab <- tab[tab$worker_id == worker, , drop = FALSE]
if (!nrow(tab)) stop('No shards assigned to ', worker)
esc <- function(x) gsub('"', '\\\\"', as.character(x), fixed = TRUE)
rows <- vapply(seq_len(nrow(tab)), function(i) {
  sprintf('{"family":"%s","engine":"%s","seed":%d}',
          esc(tab$family[i]), esc(tab$engine[i]), as.integer(tab$seed[i]))
}, character(1))
cat(sprintf('{"include":[%s]}', paste(rows, collapse = ',')))
