# Scientific Monte Carlo reference resolver for the downstream Discovery interface.
# Existing upstream generation and canonical-path implementations remain in pipeline.R.
t2_load_mc_for_discovery <- function(data, mode) {
  if (!is.null(data$scenarios)) return(data)
  if (identical(data$protocol,t2_v3_protocol())) {
    return(t2_v3_read_block(data$role,data$family,data$seed_index,data$n,
                            if(is.null(data$replications)) 500L else data$replications))
  }
  required <- c('family','seed_index','n','replications')
  if (!all(required %in% names(data))) stop('Monte Carlo reference is incomplete')
  t2_canonical_mc(mode, data$family, data$seed_index, data$n, data$replications)
}
