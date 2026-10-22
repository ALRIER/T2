#!/usr/bin/env Rscript
# Frozen-weight portfolio generalization. This script never retrains models or
# generates Monte Carlo data: it only applies archived W* vectors to archived T.

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop('Usage: Rscript scripts/confirmatory_portfolio_generalization.R STAGE [SOURCE] [TARGET] [SEED] [MODE]')
stage <- args[[1L]]
source_family <- if (length(args) >= 2L) args[[2L]] else 'all'
target_family <- if (length(args) >= 3L) args[[3L]] else 'all'
seed <- if (length(args) >= 4L) as.integer(args[[4L]]) else NA_integer_
mode <- if (length(args) >= 5L) args[[5L]] else 'full'
if (!stage %in% c('manifest', 'score', 'inference', 'report')) stop('Unsupported stage')
if (!mode %in% c('smoke', 'full')) stop('MODE must be smoke or full')

source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
t2_check_runtime('.', strict = TRUE)

pg_root <- function() Sys.getenv('T2_PORTFOLIO_ROOT', unset = 'artifacts/confirmatory_portfolio')
pg_protocol <- function() {
  p <- file.path('config', 'confirmatory_portfolio_protocol.csv')
  x <- read.csv(p, stringsAsFactors = FALSE, check.names = FALSE)
  if (!all(c('key','value','description') %in% names(x)) || anyDuplicated(x$key)) stop('Invalid portfolio protocol')
  x
}
pg_value <- function(key) { x <- pg_protocol(); x$value[match(key, x$key)] }
pg_seeds <- function(mode) if (mode == 'smoke') 21L else {
  z <- strsplit(pg_value('validation_seed_indices'), ':', fixed = TRUE)[[1L]]
  seq.int(as.integer(z[[1L]]), as.integer(z[[2L]]))
}
pg_grid <- function() {
  g <- build_contamination_grid(ga_config)
  partition_regimes(g, ga_config$training_fraction, as.integer(pg_value('training_partition_seed')))
}
pg_relation <- function(source, target) if (identical(source, target)) 'intrafamily_unseen_portfolio' else 'crossfamily_transfer_portfolio'
pg_score_root <- function(source, target, seed) file.path(pg_root(), 'scores', source, target, sprintf('seed%02d', as.integer(seed)))

write_manifest <- function() {
  g <- pg_grid(); rows <- list(); k <- 0L
  for (source in t2_families()) for (target in t2_families()) {
    keep <- g$partition == 'heldout'
    for (i in which(keep)) {
      k <- k + 1L
      rows[[k]] <- data.frame(source_family = source, target_family = target,
        relation = pg_relation(source, target), scenario_id = g$scenario_id[i],
        rate = g$rate[i], scale = g$scale[i], mechanism = g$mechanism[i],
        target_partition = g$partition[i], stringsAsFactors = FALSE)
    }
  }
  out <- do.call(rbind, rows); root <- file.path(pg_root(), 'manifest')
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  t2_write_csv(out, file.path(root, 'portfolio_manifest.csv'))
  t2_write_csv(g, file.path(root, 'scenario_partition.csv'))
  writeLines(c('# Frozen portfolio generalization manifest', '',
    '- All rows use the deterministic held-out scenario partition.',
    '- Intra-family rows test unseen combinations within the source family.',
    '- Cross-family rows test frozen source weights on a target-family portfolio.',
    '- No row is selected from confirmation performance.'), file.path(root, 'README.md'))
  invisible(out)
}

load_canonical <- function(family, seed) {
  p <- t2_mc_path('full', family, seed, as.integer(pg_value('sample_n')), as.integer(pg_value('replications')))
  if (!file.exists(p)) stop('Missing archived canonical block: ', p)
  x <- t2_read_rds(p)
  if (!identical(x$family, family) || as.integer(x$seed_index) != as.integer(seed) ||
      as.integer(x$n) != as.integer(pg_value('sample_n')) ||
      as.integer(x$replications) != as.integer(pg_value('replications')) || length(x$scenarios) != 361L)
    stop('Archived canonical block has incompatible provenance: ', p)
  x
}

score_portfolio <- function(source, target, seed, mode) {
  manifest_path <- file.path(pg_root(), 'manifest', 'portfolio_manifest.csv')
  if (!file.exists(manifest_path)) write_manifest()
  tab <- read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  tab <- tab[tab$source_family == source & tab$target_family == target, , drop = FALSE]
  if (!nrow(tab)) stop('Empty predeclared portfolio')
  if (mode == 'smoke') tab <- tab[seq_len(min(3L, nrow(tab))), , drop = FALSE]
  canonical <- load_canonical(target, seed)
  source_models <- t2_confirmatory_load_models(source)
  baseline <- source_models$reference[[1L]]
  rows <- list(); k <- 0L
  for (scenario_id in tab$scenario_id) {
    sc <- canonical$scenarios[[as.integer(scenario_id)]]
    bse <- (model_predict(sc$T, baseline) - sc$target)^2
    for (id in names(source_models$candidates)) {
      model <- source_models$candidates[[id]]; se <- (model_predict(sc$T, model) - sc$target)^2
      k <- k + 1L
      rows[[k]] <- data.frame(source_family=source, target_family=target,
        relation=pg_relation(source,target), validation_seed=as.integer(seed), scenario_id=as.integer(scenario_id),
        model_id=id, engine=sub(sprintf('^%s_', source), '', sub('_train[0-9]+$', '', id)),
        training_seed=as.integer(sub('.*_train', '', id)),
        mse=mean(se), q95=unname(quantile(se,.95,type=8)), benchmark_mse=mean(bse),
        benchmark_q95=unname(quantile(bse,.95,type=8)), mse_difference=mean(se)-mean(bse),
        q95_difference=unname(quantile(se,.95,type=8)-quantile(bse,.95,type=8)), n_rep=length(se), stringsAsFactors=FALSE)
    }
  }
  out <- do.call(rbind, rows); root <- pg_score_root(source,target,seed)
  dir.create(root, recursive=TRUE, showWarnings=FALSE)
  t2_write_csv(out, file.path(root, 'scores.csv'))
  writeLines('portfolio_score COMPLETE', file.path(root, 'score.status'))
  invisible(out)
}

infer_portfolio <- function(source, target, mode) {
  seeds <- pg_seeds(mode); all <- lapply(seeds, function(s) {
    p <- file.path(pg_score_root(source,target,s), 'scores.csv')
    if (!file.exists(p)) stop('Missing portfolio score: ', p)
    read.csv(p, stringsAsFactors=FALSE, check.names=FALSE)
  })
  x <- do.call(rbind, all)
  # One independent block is one validation seed; models remain separate here.
  by_seed <- aggregate(cbind(mse_difference,q95_difference,benchmark_mse,benchmark_q95,mse,q95) ~
                         source_family + target_family + relation + scenario_id + model_id + engine + training_seed + validation_seed,
                       x, mean)
  summarize <- function(z, unit) {
    a <- t2_confirmatory_block_test(z$mse_difference, if (mode=='smoke') 20L else t2_confirmatory_bootstrap_B('full'),
                                    t2_seed(paste(source,target,unit,z$model_id[[1L]],'mse'), 12001L))
    b <- t2_confirmatory_block_test(z$q95_difference, if (mode=='smoke') 20L else t2_confirmatory_bootstrap_B('full'),
                                    t2_seed(paste(source,target,unit,z$model_id[[1L]],'q95'), 12002L))
    data.frame(source_family=z$source_family[[1L]], target_family=z$target_family[[1L]], relation=z$relation[[1L]],
      scenario_id=z$scenario_id[[1L]], unit=unit, model_id=z$model_id[[1L]], engine=z$engine[[1L]],
      training_seed=z$training_seed[[1L]], mse_difference=a[['difference']], mse_ci_low=a[['ci_low']], mse_ci_high=a[['ci_high']], mse_p_value=a[['p_value']],
      q95_difference=b[['difference']], q95_ci_low=b[['ci_low']], q95_ci_high=b[['ci_high']], q95_p_value=b[['p_value']],
      benchmark_mse=mean(z$benchmark_mse), benchmark_q95=mean(z$benchmark_q95), n_blocks=nrow(z), stringsAsFactors=FALSE)
  }
  model_taxonomy <- do.call(rbind, lapply(split(by_seed, interaction(by_seed$scenario_id, by_seed$model_id, drop=TRUE)), summarize, unit='estimator'))
  # Adjustment is deliberately deferred to the single aggregation job.  A
  # source-target shard is not an FDR family.
  model_taxonomy$mse_q_value <- NA_real_; model_taxonomy$q95_q_value <- NA_real_
  model_taxonomy$mse_gain_pct <- -100*model_taxonomy$mse_difference/pmax(model_taxonomy$benchmark_mse,1e-12)
  model_taxonomy$q95_gain_pct <- -100*model_taxonomy$q95_difference/pmax(model_taxonomy$benchmark_q95,1e-12)
  model_taxonomy$mse_supported <- NA; model_taxonomy$q95_supported <- NA; model_taxonomy$evidence_taxonomy <- 'pending_global_fdr'
  # Engine summaries average the eight frozen estimators within each independent
  # validation seed; individual estimator results above are never discarded.
  engine_by_seed <- aggregate(cbind(mse_difference,q95_difference,benchmark_mse,benchmark_q95,mse,q95) ~
                                source_family + target_family + relation + scenario_id + engine + validation_seed,
                              by_seed, mean)
  engine_by_seed$model_id <- engine_by_seed$engine; engine_by_seed$training_seed <- NA_integer_
  engine_taxonomy <- do.call(rbind, lapply(split(engine_by_seed, interaction(engine_by_seed$scenario_id, engine_by_seed$engine, drop=TRUE)), summarize, unit='engine'))
  engine_taxonomy$mse_q_value <- NA_real_; engine_taxonomy$q95_q_value <- NA_real_
  engine_taxonomy$mse_gain_pct <- -100*engine_taxonomy$mse_difference/pmax(engine_taxonomy$benchmark_mse,1e-12)
  engine_taxonomy$q95_gain_pct <- -100*engine_taxonomy$q95_difference/pmax(engine_taxonomy$benchmark_q95,1e-12)
  engine_taxonomy$mse_supported <- NA; engine_taxonomy$q95_supported <- NA; engine_taxonomy$evidence_taxonomy <- 'pending_global_fdr'
  region <- read.csv(file.path(pg_root(), 'manifest', 'portfolio_manifest.csv'), stringsAsFactors=FALSE, check.names=FALSE)
  region <- region[region$source_family == source & region$target_family == target,
                   c('source_family','target_family','relation','scenario_id','rate','scale','mechanism'), drop=FALSE]
  model_taxonomy <- merge(model_taxonomy, region,
                          by=c('source_family','target_family','relation','scenario_id'), all.x=TRUE, sort=FALSE)
  engine_taxonomy <- merge(engine_taxonomy, region,
                           by=c('source_family','target_family','relation','scenario_id'), all.x=TRUE, sort=FALSE)
  winners <- do.call(rbind, lapply(split(model_taxonomy, model_taxonomy$scenario_id), function(z) {
    data.frame(source_family=source,target_family=target,relation=z$relation[[1L]],scenario_id=z$scenario_id[[1L]],
      mse_winner=z$model_id[which.min(z$mse_difference)][1L], q95_winner=z$model_id[which.min(z$q95_difference)][1L],
      pareto_winner=if (identical(z$model_id[which.min(z$mse_difference)][1L], z$model_id[which.min(z$q95_difference)][1L])) z$model_id[which.min(z$mse_difference)][1L] else NA_character_, stringsAsFactors=FALSE)
  }))
  engine_winners <- do.call(rbind, lapply(split(engine_taxonomy, engine_taxonomy$scenario_id), function(z) {
    data.frame(source_family=source,target_family=target,relation=z$relation[[1L]],scenario_id=z$scenario_id[[1L]],
      mse_winner=z$engine[which.min(z$mse_difference)][1L], q95_winner=z$engine[which.min(z$q95_difference)][1L],
      pareto_winner=if (identical(z$engine[which.min(z$mse_difference)][1L], z$engine[which.min(z$q95_difference)][1L])) z$engine[which.min(z$mse_difference)][1L] else NA_character_, stringsAsFactors=FALSE)
  }))
  root <- file.path(pg_root(),'inference',source,target); dir.create(root,recursive=TRUE,showWarnings=FALSE)
  t2_write_csv(model_taxonomy, file.path(root,'estimator_region_taxonomy.csv'))
  t2_write_csv(engine_taxonomy, file.path(root,'engine_region_taxonomy.csv'))
  t2_write_csv(winners, file.path(root,'regional_winners.csv'))
  t2_write_csv(engine_winners, file.path(root,'engine_regional_winners.csv'))
  writeLines('portfolio_inference COMPLETE', file.path(root,'inference.status'))
  invisible(model_taxonomy)
}

report_portfolio <- function() {
  root <- file.path(pg_root(), 'inference')
  estimator_files <- list.files(root, 'estimator_region_taxonomy.csv$', recursive=TRUE, full.names=TRUE)
  engine_files <- list.files(root, 'engine_region_taxonomy.csv$', recursive=TRUE, full.names=TRUE)
  estimator_winner_files <- list.files(root, '^regional_winners.csv$', recursive=TRUE, full.names=TRUE)
  engine_winner_files <- list.files(root, '^engine_regional_winners.csv$', recursive=TRUE, full.names=TRUE)
  if (!length(estimator_files) || !length(engine_files) || !length(estimator_winner_files) || !length(engine_winner_files))
    stop('Portfolio report requires completed inference for every planned source-target pair')
  estimator <- do.call(rbind, lapply(estimator_files, read.csv, stringsAsFactors=FALSE, check.names=FALSE))
  engine <- do.call(rbind, lapply(engine_files, read.csv, stringsAsFactors=FALSE, check.names=FALSE))
  # One declared multiplicity family per metric and analysis level across the
  # complete source->target matrix—not 36 independent shard corrections.
  classify <- function(z) {
    z$mse_q_value <- p.adjust(z$mse_p_value, 'BH'); z$q95_q_value <- p.adjust(z$q95_p_value, 'BH')
    z$mse_supported <- z$mse_difference < 0 & z$mse_ci_high < 0 & z$mse_q_value <= .05
    z$q95_supported <- z$q95_difference < 0 & z$q95_ci_high < 0 & z$q95_q_value <= .05
    z$evidence_taxonomy <- ifelse(z$mse_supported & z$q95_supported,'mse_and_q95',ifelse(z$mse_supported,'mse_only',ifelse(z$q95_supported,'q95_only','neither_metric')))
    z
  }
  estimator <- classify(estimator); engine <- classify(engine)
  long_winners <- function(paths, label) do.call(rbind, lapply(paths, function(p) {
    z <- read.csv(p, stringsAsFactors=FALSE, check.names=FALSE)
    do.call(rbind, lapply(c('mse_winner','q95_winner','pareto_winner'), function(metric) {
      data.frame(source_family=z$source_family,target_family=z$target_family,relation=z$relation,
        scenario_id=z$scenario_id,metric=sub('_winner$','',metric),winner=z[[metric]],winner_level=label,stringsAsFactors=FALSE)
    }))
  }))
  estimator_winners <- long_winners(estimator_winner_files, 'estimator')
  engine_winners <- long_winners(engine_winner_files, 'engine')
  estimator_winners <- estimator_winners[!is.na(estimator_winners$winner) & nzchar(estimator_winners$winner),,drop=FALSE]
  engine_winners <- engine_winners[!is.na(engine_winners$winner) & nzchar(engine_winners$winner),,drop=FALSE]
  win_summary <- function(z, id) {
    out <- aggregate(rep(1L,nrow(z)), by=z[c('winner_level','source_family','target_family','relation','metric','winner')], FUN=sum)
    names(out)[ncol(out)] <- 'regional_wins'; names(out)[names(out) == 'winner'] <- id; out
  }
  # Keep a common winner identifier column across levels; winner_level identifies
  # estimator and engine rows, avoiding invalid rbind column-name mismatches.
  championship <- rbind(win_summary(estimator_winners, 'winner'),
                        win_summary(engine_winners, 'winner'))
  out_root <- file.path(pg_root(), 'report'); dir.create(out_root, recursive=TRUE, showWarnings=FALSE)
  t2_write_csv(estimator, file.path(out_root, 'estimator_region_taxonomy_all.csv'))
  t2_write_csv(engine, file.path(out_root, 'engine_region_taxonomy_all.csv'))
  t2_write_csv(estimator_winners, file.path(out_root, 'estimator_regional_winners_all.csv'))
  t2_write_csv(engine_winners, file.path(out_root, 'engine_regional_winners_all.csv'))
  t2_write_csv(championship, file.path(out_root, 'championship_coverage.csv'))
  writeLines(c('# Frozen portfolio generalization report', '',
    paste0('- estimator-region rows: ', nrow(estimator)),
    paste0('- engine-region rows: ', nrow(engine)),
    '- Regional winner tables retain MSE, q95 and Pareto outcomes separately.',
    '- Championship coverage is a tournament summary; it does not invalidate local winners.'),
    file.path(out_root, 'README.md'))
  writeLines('portfolio_report COMPLETE', file.path(out_root, 'report.status'))
  invisible(championship)
}

if (stage == 'manifest') write_manifest()
if (stage == 'score') {
  if (!source_family %in% t2_families() || !target_family %in% t2_families() || is.na(seed) || !seed %in% pg_seeds(mode)) stop('Invalid source, target, or validation seed')
  score_portfolio(source_family,target_family,seed,mode)
}
if (stage == 'inference') {
  if (!source_family %in% t2_families() || !target_family %in% t2_families()) stop('Invalid source or target family')
  infer_portfolio(source_family,target_family,mode)
}
if (stage == 'report') report_portfolio()
cat('PORTFOLIO GENERALIZATION', stage, source_family, target_family, ifelse(is.na(seed),'',seed), mode, 'COMPLETE\n')
