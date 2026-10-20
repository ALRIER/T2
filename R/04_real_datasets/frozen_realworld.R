realworld_frozen_comparison <- function(sample_matrix,weights,reference_mean,eligible=rep(TRUE,26L)) {
  # sample_matrix is the 26-component matrix computed on resamples of ONE dataset.
  # Full-data mean is a PROXY for the unknown true population mean.
  evaluate_weights(sample_matrix,weights,reference_mean,eligible)
}
realworld_fdr <- function(predeclared_p_values,alpha=.05) {
  q<-p.adjust(predeclared_p_values,method='BH')
  data.frame(p=predeclared_p_values,q=q,pass=q<=alpha)
}
