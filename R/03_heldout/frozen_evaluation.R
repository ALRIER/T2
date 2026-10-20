evaluate_frozen <- function(T,weights,target,eligible=rep(TRUE,26L),batch_size=32L) {
  # NO weight updates: invoke only on reserved Monte Carlo replicates and regimes.
  evaluate_weights(T,weights,target,eligible,batch_size)
}
heldout_fdr <- function(p,alpha=.05) {
  # Requires independently computed, valid predeclared p-values.
  q <- p.adjust(p,'BH');data.frame(p=p,q=q,confirmed=q<=alpha)
}
