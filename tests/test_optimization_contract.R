source('R/00_shared/load_all.R'); t2_load('.')
set.seed(31)
brute <- function(O) which(vapply(seq_len(nrow(O)), function(i)
  !any(vapply(setdiff(seq_len(nrow(O)), i), function(j) dominates(O[j,], O[i,]), logical(1))), logical(1)))
for (n in c(1L, 2L, 10L, 150L)) {
  O <- matrix(sample(0:7, n * 2L, replace=TRUE), ncol=2L)
  stopifnot(identical(sort(pareto_front(O)), sort(brute(O))))
}
T <- matrix(rnorm(40L * 26L), 40L, 26L)
W <- normalize_weights(matrix(rexp(26L * 12L), 26L, 12L))
sc <- lapply(c('clean','low','intermediate','high'), function(b)
  list(T=T, target=0, band=b, eligible=rep(TRUE,26L),
       benchmark=precompute_benchmarks(T, 0)))
old <- do.call(rbind, lapply(sc, function(s)
  evaluate_weights(s$T, W, s$target, s$eligible, benchmark=s$benchmark)$objectives))
new <- nsga_evaluate_scenarios(W, sc)
expected <- (old[1:12,,drop=FALSE] + old[13:24,,drop=FALSE] +
             old[25:36,,drop=FALSE] + old[37:48,,drop=FALSE]) / 4
stopifnot(isTRUE(all.equal(new, expected, tolerance=1e-12)))
cat('OPTIMIZATION EQUIVALENCE CONTRACT PASS\n')
