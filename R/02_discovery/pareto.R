dominates <- function(a,b) all(a<=b) && any(a<b)
pareto_front <- function(O) {
  O<-as.matrix(O); stopifnot(all(is.finite(O)))
  which(vapply(seq_len(nrow(O)),function(i) !any(vapply(setdiff(seq_len(nrow(O)),i),function(j) dominates(O[j,],O[i,]),logical(1))),logical(1)))
}
bh_training_diagnostic <- function(p) {
  # Exploratory only: training selection and testing share data.
  p.adjust(p,method='BH')
}
