args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], mustWork = TRUE) else normalizePath('.', mustWork = TRUE)
source(file.path(root, 'R/00_shared/runtime_contract.R'))
z <- t2_check_runtime(root, strict = FALSE)
cat('T2 runtime status:', z$status, '\n')
cat('R:', z$R, '\n')
cat('RNG:', paste(z$rng, collapse = '/'), '\n')
if (length(z$problems)) {
  cat(paste('-', z$problems, collapse = '\n'), '\n')
  quit(save = 'no', status = 1L)
}
cat('RUNTIME CONTRACT PASS\n')
