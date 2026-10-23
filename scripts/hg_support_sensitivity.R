#!/usr/bin/env Rscript
# Frozen-weight sensitivity audit for the two positive-support-only components.
# It never changes discovery outputs or the primary W* analysis.
args <- commandArgs(trailingOnly = TRUE)
stage <- if (length(args)) args[[1L]] else stop('Usage: audit|match|score|infer [batch]')
batch <- if (length(args) > 1L) as.integer(args[[2L]]) else NA_integer_
root <- Sys.getenv('HG_ROOT', 'artifacts/hg_support_sensitivity')
data_root <- Sys.getenv('HG_DATA_ROOT', file.path(root, 'data', 'T2_rw2_external_catalog_664'))
source('R/00_shared/load_all.R'); t2_load('.'); source('R/00_shared/pipeline.R')
dir.create(root, recursive = TRUE, showWarnings = FALSE)
families <- c('normal','lognormal','weibull','invgauss','exgaussian','exwald')
positive_components <- c('harmonic','geometric')

relation <- function(f, p) {
  direct <- switch(f, normal=p=='normal_like', lognormal=p=='lognormal_like', weibull=p=='weibull_like',
    invgauss=p %in% c('lognormal_like','weibull_like'), exgaussian=p %in% c('normal_like','lognormal_like'),
    exwald=p %in% c('lognormal_like','weibull_like'))
  near <- switch(f, normal=p=='empirical_unknown', lognormal=p=='weibull_like', weibull=p=='lognormal_like',
    invgauss=p=='empirical_unknown', exgaussian=p %in% c('weibull_like','empirical_unknown'), exwald=p=='empirical_unknown')
  if (isTRUE(direct)) 'direct_intraregime' else if (isTRUE(near)) 'near_intrfamily' else 'crossfamily_transfer'
}
benchmark <- function(p) if (p=='normal_like') 'mean' else if (p=='empirical_unknown') 'huber' else 'trimmed20'
depth_vectors <- function(x) {
  q <- quantile(x, c(.1,.75,.9), na.rm=TRUE, type=8)
  out <- list(full=x, body_10_90=x[x>=q[1] & x<=q[3]])
  tail <- x[x>=q[2]]; if (length(tail)>=150L) out$upper_tail <- tail
  out[vapply(out,length,integer(1))>=150L]
}
masked_model <- function(model) {
  w <- as.numeric(model$weights); names(w) <- ESTIMATOR_NAMES
  w[positive_components] <- 0
  if (sum(w) <= 0) stop('Ablation removed all model weight: ', model$id)
  new_frozen_model(paste0(model$id, '__hg_ablated'), weights=w, family=model$family)
}
prepare_with_exposure <- function(x, sample_sizes, R, seed) {
  x <- as.numeric(x); x <- x[is.finite(x)]; theta <- mean(x); set.seed(seed)
  lapply(sample_sizes, function(n) {
    draws <- replicate(R, sample(x, n, replace=TRUE))
    samples <- lapply(seq_len(R), function(i) draws[,i])
    positive_n <- colSums(draws > 0)
    list(T=component_matrix(samples), target=theta, sample_n=n,
         nonpositive_rate=mean(draws <= 0), mixed_support_rate=mean(positive_n > 0 & positive_n < n),
         no_positive_rate=mean(positive_n == 0), positive_only_rate=mean(positive_n == n))
  })
}
block_test <- function(z, prefix) {
  a <- t2_confirmatory_block_test(z[[paste0(prefix,'_mse_difference')]], t2_confirmatory_bootstrap_B('full'),
    t2_seed(paste(z$source_family[1], z$proximity_layer[1], z$model_id[1], prefix, 'mse'), 19001L))
  q <- t2_confirmatory_block_test(z[[paste0(prefix,'_q95_difference')]], t2_confirmatory_bootstrap_B('full'),
    t2_seed(paste(z$source_family[1], z$proximity_layer[1], z$model_id[1], prefix, 'q95'), 19002L))
  c(mse_difference=unname(a['difference']), mse_ci_high=unname(a['ci_high']), mse_p_value=unname(a['p_value']),
    q95_difference=unname(q['difference']), q95_ci_high=unname(q['ci_high']), q95_p_value=unname(q['p_value']))
}

if (stage == 'audit') {
  manifest <- t2_confirmatory_model_manifest(); rows <- lapply(seq_len(nrow(manifest)), function(i) {
    w <- read.csv(manifest$weights_path[i], stringsAsFactors=FALSE, check.names=FALSE)
    data.frame(model_id=manifest$model_id[i], family=manifest$family[i], engine=manifest$engine[i],
      training_seed=manifest$training_seed[i], harmonic_weight=w$weight[match('harmonic',w$component)],
      geometric_weight=w$weight[match('geometric',w$component)], stringsAsFactors=FALSE)
  })
  out <- do.call(rbind, rows); out$hg_weight <- out$harmonic_weight + out$geometric_weight
  out$has_hg_weight <- out$hg_weight > 0
  write.csv(out, file.path(root,'frozen_weight_audit.csv'), row.names=FALSE)
  writeLines('HG_AUDIT_COMPLETE', file.path(root,'audit.status'))
} else if (stage == 'match') {
  p <- file.path(data_root,'profile_registry.csv'); if (!file.exists(p)) stop('Profile registry missing')
  x <- read.csv(p,stringsAsFactors=FALSE); x <- x[x$load_ok %in% TRUE,,drop=FALSE]
  rows <- do.call(rbind,lapply(families,function(f) transform(x,source_family=f,
    proximity_layer=vapply(empirical_profile,function(p) relation(f,p),character(1)))))
  rows$matching_rule <- 'v2_profile_anchor_pre_score_v1'
  write.csv(rows,file.path(root,'regime_match_manifest.csv'),row.names=FALSE)
  writeLines('HG_MATCH_COMPLETE',file.path(root,'match.status'))
} else if (stage == 'score') {
  if (!is.finite(batch) || batch < 1L) stop('Score requires batch')
  m <- read.csv(file.path(root,'regime_match_manifest.csv'),stringsAsFactors=FALSE)
  ids <- sort(unique(m$dataset_id)); groups <- split(ids, ceiling(seq_along(ids)/10)); ids <- groups[[batch]]
  if (is.null(ids)) stop('Unknown score batch')
  reps <- as.integer(Sys.getenv('HG_REPS','500')); ns <- as.integer(strsplit(Sys.getenv('HG_SAMPLE_SIZES','200|1000'),'|',fixed=TRUE)[[1]])
  ans <- list(); exposure <- list(); k <- 0L; e <- 0L
  for (id in ids) {
    raw <- file.path(data_root,'raw',paste0(id,'.rds')); if (!file.exists(raw)) stop('Missing immutable raw input: ',id)
    x <- readRDS(raw); sub <- m[m$dataset_id==id,,drop=FALSE]
    for (depth in names(depth_vectors(x))) {
      xx <- depth_vectors(x)[[depth]]; prep <- prepare_with_exposure(xx, ns, reps, t2_seed(paste(id,depth),15001L))
      for (f in families) {
        zf <- sub[sub$source_family==f,,drop=FALSE]; mods <- t2_confirmatory_load_models(f)
        ref <- mods$reference[[match(benchmark(zf$empirical_profile[1]),vapply(mods$reference,`[[`,character(1),'component'))]]
        for (z in prep) {
          e <- e+1L; exposure[[e]] <- data.frame(parent_dataset_id=zf$parent_dataset_id[1],dataset_id=id,source_family=f,
            proximity_layer=zf$proximity_layer[1],depth=depth,sample_n=z$sample_n,nonpositive_rate=z$nonpositive_rate,
            mixed_support_rate=z$mixed_support_rate,no_positive_rate=z$no_positive_rate,positive_only_rate=z$positive_only_rate)
          bse <- (model_predict(z$T,ref)-z$target)^2
          for (mid in names(mods$candidates)) {
            original <- mods$candidates[[mid]]; ablated <- masked_model(original)
            ose <- (model_predict(z$T,original)-z$target)^2; ase <- (model_predict(z$T,ablated)-z$target)^2; k <- k+1L
            ans[[k]] <- data.frame(parent_dataset_id=zf$parent_dataset_id[1],dataset_id=id,source_family=f,
              proximity_layer=zf$proximity_layer[1],empirical_profile=zf$empirical_profile[1],depth=depth,sample_n=z$sample_n,
              model_id=mid,engine=sub(sprintf('^%s_',f),'',sub('_train[0-9]+$','',mid)),
              original_mse_difference=mean(ose)-mean(bse), original_q95_difference=unname(quantile(ose,.95,type=8)-quantile(bse,.95,type=8)),
              ablated_mse_difference=mean(ase)-mean(bse), ablated_q95_difference=unname(quantile(ase,.95,type=8)-quantile(bse,.95,type=8)),
              original_minus_ablated_mse=mean(ose)-mean(ase), original_minus_ablated_q95=unname(quantile(ose,.95,type=8)-quantile(ase,.95,type=8)),
              benchmark_mse=mean(bse),benchmark_q95=unname(quantile(bse,.95,type=8)),stringsAsFactors=FALSE)
          }
        }
      }
    }
  }
  d <- file.path(root,sprintf('scores_batch_%03d',batch)); dir.create(d,recursive=TRUE,showWarnings=FALSE)
  saveRDS(do.call(rbind,ans),file.path(d,'scores.rds')); write.csv(do.call(rbind,ans),file.path(d,'scores.csv'),row.names=FALSE)
  write.csv(unique(do.call(rbind,exposure)),file.path(d,'exposure.csv'),row.names=FALSE)
  writeLines('HG_SCORE_COMPLETE',file.path(d,'score.status'))
} else if (stage == 'infer') {
  fs <- list.files(root,'scores.rds$',recursive=TRUE,full.names=TRUE); if (!length(fs)) stop('No score shards')
  x <- do.call(rbind,lapply(fs,readRDS)); efs <- list.files(root,'exposure.csv$',recursive=TRUE,full.names=TRUE)
  b <- aggregate(cbind(original_mse_difference,original_q95_difference,ablated_mse_difference,ablated_q95_difference,
    original_minus_ablated_mse,original_minus_ablated_q95,benchmark_mse,benchmark_q95)~parent_dataset_id+source_family+proximity_layer+model_id+engine,x,mean)
  key <- interaction(b$source_family,b$proximity_layer,b$model_id,drop=TRUE)
  out <- do.call(rbind,lapply(split(b,key),function(z) {
    o <- block_test(z,'original'); a <- block_test(z,'ablated')
    dm <- t2_confirmatory_block_test(z$original_minus_ablated_mse,t2_confirmatory_bootstrap_B('full'),t2_seed(paste(z$model_id[1],'delta_mse'),19003L))
    dq <- t2_confirmatory_block_test(z$original_minus_ablated_q95,t2_confirmatory_bootstrap_B('full'),t2_seed(paste(z$model_id[1],'delta_q95'),19004L))
    data.frame(source_family=z$source_family[1], proximity_layer=z$proximity_layer[1], model_id=z$model_id[1], engine=z$engine[1], n_parent=nrow(z),
      as.data.frame(as.list(setNames(o, paste0('original_', names(o))))),
      as.data.frame(as.list(setNames(a, paste0('ablated_', names(a))))),
      delta_mse=unname(dm['difference']),delta_mse_ci_high=unname(dm['ci_high']),delta_mse_p_value=unname(dm['p_value']),
      delta_q95=unname(dq['difference']),delta_q95_ci_high=unname(dq['ci_high']),delta_q95_p_value=unname(dq['p_value']),
      benchmark_mse=mean(z$benchmark_mse),benchmark_q95=mean(z$benchmark_q95),check.names=FALSE)
  }))
  for (v in c('original_mse','original_q95','ablated_mse','ablated_q95')) out[[paste0(v,'_q_value')]] <- ave(out[[paste0(v,'_p_value')]],out$proximity_layer,FUN=function(p)p.adjust(p,'BH'))
  label <- function(prefix) { m <- out[[paste0(prefix,'_mse_difference')]]<0 & out[[paste0(prefix,'_mse_ci_high')]]<0 & out[[paste0(prefix,'_mse_q_value')]]<=.05; q <- out[[paste0(prefix,'_q95_difference')]]<0 & out[[paste0(prefix,'_q95_ci_high')]]<0 & out[[paste0(prefix,'_q95_q_value')]]<=.05; ifelse(m&q,'mse_and_q95_bh_fdr',ifelse(m,'mse_only_bh_fdr',ifelse(q,'q95_only_bh_fdr','no_supported_gain'))) }
  out$original_taxonomy <- label('original'); out$ablated_taxonomy <- label('ablated'); out$taxonomy_changed <- out$original_taxonomy != out$ablated_taxonomy
  out$original_mse_gain_pct <- -100*out$original_mse_difference/pmax(out$benchmark_mse,1e-12); out$ablated_mse_gain_pct <- -100*out$ablated_mse_difference/pmax(out$benchmark_mse,1e-12)
  out$original_q95_gain_pct <- -100*out$original_q95_difference/pmax(out$benchmark_q95,1e-12); out$ablated_q95_gain_pct <- -100*out$ablated_q95_difference/pmax(out$benchmark_q95,1e-12)
  write.csv(out,file.path(root,'hg_support_sensitivity_taxonomy.csv'),row.names=FALSE)
  if (length(efs)) write.csv(do.call(rbind,lapply(efs,read.csv)),file.path(root,'hg_support_exposure.csv'),row.names=FALSE)
  writeLines('HG_INFERENCE_COMPLETE',file.path(root,'inference.status'))
} else stop('Unknown stage')
