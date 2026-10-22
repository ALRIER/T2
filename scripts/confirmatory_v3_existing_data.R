#!/usr/bin/env Rscript
# Consume immutable canonical validation artifacts without regenerating data.
# This layer adds stress scoring, bundle-backed real-world scoring/inference,
# and a joint report to the completed confirmatory-v2 Monte Carlo inference.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L)
  stop('Usage: Rscript scripts/confirmatory_v3_existing_data.R STAGE [FAMILY] [SEED]')
stage <- args[[1L]]
family <- if (length(args) >= 2L) args[[2L]] else 'all'
seed <- if (length(args) >= 3L) as.integer(args[[3L]]) else NA_integer_
valid <- c('stress_score', 'stress_inference', 'realworld_score',
           'realworld_inference', 'selection', 'report')
if (!stage %in% valid) stop('Unsupported stage: ', stage)

source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
t2_check_runtime('.', strict = TRUE)
if (!family %in% c(t2_families(), 'all')) stop('Invalid family: ', family)

v3_root <- function() Sys.getenv('T2_CONFIRMATORY_V3_ROOT', unset = 'artifacts/confirmatory_v3')
stress_root <- function(fam = family, s = seed)
  file.path(v3_root(), 'stress', fam, sprintf('seed%02d', as.integer(s)))

load_canonical <- function(fam, s, n, reps) {
  path <- t2_mc_path('full', fam, s, n, reps)
  if (!file.exists(path)) stop('Missing canonical validation artifact: ', path)
  x <- t2_read_rds(path)
  if (!identical(x$family, fam) || !identical(as.integer(x$seed_index), as.integer(s)) ||
      !identical(as.integer(x$n), as.integer(n)) ||
      !identical(as.integer(x$replications), as.integer(reps)) ||
      !identical(x$mc_version, t2_mc_version()) || length(x$scenarios) != 361L)
    stop('Canonical validation provenance mismatch: ', path)
  x
}

score_stress <- function(fam, s) {
  n <- as.integer(Sys.getenv('T2_STRESS_SAMPLE_N', '1000'))
  reps <- as.integer(Sys.getenv('T2_STRESS_REPS', '250'))
  x <- load_canonical(fam, s, n, reps)
  models <- t2_confirmatory_load_models(fam)
  root <- stress_root(fam, s); dir.create(root, recursive = TRUE, showWarnings = FALSE)
  raw <- vector('list', length(x$scenarios)); rows <- list(); k <- 0L
  for (i in seq_along(x$scenarios)) {
    sc <- x$scenarios[[i]]
    benchmark_se <- (model_predict(sc$T, models$reference[[1L]]) - sc$target)^2
    se <- do.call(cbind, lapply(models$candidates, function(m)
      (model_predict(sc$T, m) - sc$target)^2))
    colnames(se) <- names(models$candidates)
    raw[[i]] <- list(family=fam, validation_seed=as.integer(s), sample_n=n,
      scenario_id=sc$scenario_id, band=sc$band, rate=sc$rate, mechanism=sc$mechanism,
      benchmark_se=benchmark_se, candidate_ids=colnames(se), candidate_se=se,
      replications=nrow(se))
    rows[[length(rows) + 1L]] <- do.call(rbind, lapply(seq_len(ncol(se)), function(j) {
      id <- colnames(se)[j]
      data.frame(family=fam, engine=sub(sprintf('^%s_', fam), '', sub('_train[0-9]+$', '', id)),
        model_id=id, training_seed=as.integer(sub('.*_train', '', id)),
        validation_seed=as.integer(s), scenario_id=sc$scenario_id, sample_n=n,
        rate=sc$rate, mechanism=sc$mechanism, mse=mean(se[,j]),
        q95=unname(quantile(se[,j], .95, type=8)),
        benchmark_mse=mean(benchmark_se), benchmark_q95=unname(quantile(benchmark_se, .95, type=8)),
        n_rep=nrow(se), stringsAsFactors=FALSE)
    }))
  }
  t2_atomic_save(raw, file.path(root, 'raw_errors.rds'))
  t2_write_csv(do.call(rbind, rows), file.path(root, 'scores.csv'))
  t2_write_csv(data.frame(family=fam, validation_seed=as.integer(s), sample_n=n,
    replications=reps, scenario_count=length(x$scenarios), mc_version=x$mc_version,
    stringsAsFactors=FALSE), file.path(root, 'provenance.csv'))
  writeLines(sprintf('confirmatory_v3_stress_score %s seed%02d COMPLETE', fam, s),
             file.path(root, 'score.status'))
  invisible(root)
}

stress_inference <- function(fam) {
  seeds <- 21:26; block_rows <- list(); stability <- list()
  for (s in seeds) {
    path <- file.path(stress_root(fam, s), 'raw_errors.rds')
    if (!file.exists(path)) stop('Missing stress score: ', path)
    entries <- t2_read_rds(path)
    for (engine in c('ga', 'nsga2', 'de', 'dirichlet')) {
      rows <- list()
      for (entry in entries) {
        ids <- grep(sprintf('^%s_%s_train', fam, engine), entry$candidate_ids, value=TRUE)
        if (length(ids) != 8L) stop('Expected eight frozen models for ', fam, '/', engine)
        for (id in ids) {
          j <- match(id, entry$candidate_ids); cse <- entry$candidate_se[,j]
          rows[[length(rows)+1L]] <- data.frame(
            model_id=id, training_seed=as.integer(sub('.*_train', '', id)),
            mse_difference=mean(cse)-mean(entry$benchmark_se),
            q95_difference=unname(quantile(cse,.95,type=8)-
                                  quantile(entry$benchmark_se,.95,type=8)),
            benchmark_mse=mean(entry$benchmark_se),
            benchmark_q95=unname(quantile(entry$benchmark_se,.95,type=8)),
            stringsAsFactors=FALSE)
        }
      }
      rr <- do.call(rbind, rows)
      per_model <- aggregate(cbind(mse_difference,q95_difference,benchmark_mse,benchmark_q95) ~
                              model_id + training_seed, rr, mean)
      block <- aggregate(cbind(mse_difference,q95_difference,benchmark_mse,benchmark_q95) ~ 1,
                         per_model, mean)
      block_rows[[length(block_rows)+1L]] <- data.frame(
        family=fam, engine=engine, validation_seed=as.integer(s),
        mse_difference=block$mse_difference, q95_difference=block$q95_difference,
        benchmark_mse=block$benchmark_mse, benchmark_q95=block$benchmark_q95,
        n_training_models=nrow(per_model), stringsAsFactors=FALSE)
      stability[[length(stability)+1L]] <- transform(per_model,
        family=fam, engine=engine, validation_seed=as.integer(s))
    }
  }
  blocks <- do.call(rbind, block_rows); stable <- do.call(rbind, stability)
  primary <- do.call(rbind, lapply(split(blocks, blocks$engine), function(z) {
    a <- t2_confirmatory_block_test(z$mse_difference, t2_confirmatory_bootstrap_B('full'),
                                    t2_seed(paste(fam, unique(z$engine), 'stress_mse'), 10101L))
    b <- t2_confirmatory_block_test(z$q95_difference, t2_confirmatory_bootstrap_B('full'),
                                    t2_seed(paste(fam, unique(z$engine), 'stress_q95'), 10102L))
    data.frame(family=fam, engine=unique(z$engine),
      mse_difference=a[['difference']], mse_ci_low=a[['ci_low']], mse_ci_high=a[['ci_high']],
      mse_p_value=a[['p_value']], q95_difference=b[['difference']],
      q95_ci_low=b[['ci_low']], q95_ci_high=b[['ci_high']], q95_p_value=b[['p_value']],
      benchmark_mse=mean(z$benchmark_mse), benchmark_q95=mean(z$benchmark_q95),
      n_stress_blocks=nrow(z), n_training_models=unique(z$n_training_models),
      stringsAsFactors=FALSE)
  }))
  root <- file.path(v3_root(), 'stress_inference', fam)
  dir.create(root, recursive=TRUE, showWarnings=FALSE)
  t2_write_csv(blocks, file.path(root, 'stress_seed_blocks.csv'))
  t2_write_csv(stable, file.path(root, 'training_seed_stability.csv'))
  t2_write_csv(primary, file.path(root, 'stress_primary.csv'))
  writeLines(sprintf('confirmatory_v3_stress_inference %s COMPLETE', fam),
             file.path(root, 'inference.status'))
  invisible(primary)
}

layer_table <- function(x, prefix) {
  x$mse_q_value <- p.adjust(x$mse_p_value, 'BH')
  x$q95_q_value <- p.adjust(x$q95_p_value, 'BH')
  out <- data.frame(key=paste(x$family,x$engine,sep='/'), family=x$family, engine=x$engine,
                    stringsAsFactors=FALSE)
  for (nm in c('mse_difference','mse_ci_low','mse_ci_high','mse_p_value','mse_q_value',
               'q95_difference','q95_ci_low','q95_ci_high','q95_p_value','q95_q_value',
               'benchmark_mse','benchmark_q95'))
    out[[paste0(prefix,'_',nm)]] <- x[[nm]]
  out[[paste0(prefix,'_mse_gain_pct')]] <- -100*x$mse_difference/pmax(x$benchmark_mse,1e-12)
  out[[paste0(prefix,'_q95_gain_pct')]] <- -100*x$q95_difference/pmax(x$benchmark_q95,1e-12)
  out[[paste0(prefix,'_mse_confirmed')]] <- x$mse_difference < 0 & x$mse_ci_high < 0 & x$mse_q_value <= .05
  out[[paste0(prefix,'_q95_confirmed')]] <- x$q95_difference < 0 & x$q95_ci_high < 0 & x$q95_q_value <= .05
  out[[paste0(prefix,'_both_confirmed')]] <- out[[paste0(prefix,'_mse_confirmed')]] & out[[paste0(prefix,'_q95_confirmed')]]
  out
}

joint_report <- function() {
  fams <- t2_families()
  mc <- do.call(rbind, lapply(fams, function(f) {
    p <- file.path(Sys.getenv('T2_MC_INFERENCE_ROOT','artifacts/confirmatory_v2/inference'), f, 'primary_inference.csv')
    if (!file.exists(p)) stop('Missing Monte Carlo inference: ', p)
    read.csv(p, stringsAsFactors=FALSE, check.names=FALSE)
  }))
  st <- do.call(rbind, lapply(fams, function(f) {
    p <- file.path(v3_root(),'stress_inference',f,'stress_primary.csv')
    if (!file.exists(p)) stop('Missing stress inference: ', p)
    read.csv(p, stringsAsFactors=FALSE, check.names=FALSE)
  }))
  rw_path <- file.path(v3_root(),'realworld','primary_inference.csv')
  if (!file.exists(rw_path)) stop('Missing real-world inference: ', rw_path)
  rw <- read.csv(rw_path, stringsAsFactors=FALSE, check.names=FALSE)
  final <- Reduce(function(a,b) merge(a,b,by=c('key','family','engine'),all=FALSE),
                  list(layer_table(mc,'mc'), layer_table(st,'stress'), layer_table(rw,'realworld')))
  final$final_mse_confirmed <- final$mc_mse_confirmed & final$stress_mse_confirmed & final$realworld_mse_confirmed
  final$final_q95_confirmed <- final$mc_q95_confirmed & final$stress_q95_confirmed & final$realworld_q95_confirmed
  final$final_both_confirmed <- final$final_mse_confirmed & final$final_q95_confirmed
  root <- file.path(v3_root(),'report'); dir.create(root,recursive=TRUE,showWarnings=FALSE)
  t2_write_csv(final,file.path(root,'final_family_engine_summary.csv'))
  t2_write_csv(final[final$final_both_confirmed,c('family','engine'),drop=FALSE],
               file.path(root,'final_joint_confirmed_winners.csv'))
  writeLines(c('# T2 confirmatory reuse report','',
    paste0('- family-engine hypotheses: ',nrow(final)),
    paste0('- joint MSE+q95 confirmations across Monte Carlo, stress and real-world: ',sum(final$final_both_confirmed)),
    '', 'All three evidence layers are required for the joint-confirmed label.'),
    file.path(root,'confirmatory_v3_report.md'))
  writeLines('confirmatory_v3_report COMPLETE',file.path(root,'report.status'))
  invisible(final)
}

# This is deliberately separate from real-world scoring.  Seeds 21--26 form
# one locked synthetic confirmation layer: stress is an adverse-condition
# analysis of the same independent seed blocks, not a second independent
# held-out panel.  The resulting manifest freezes the family/engine scope
# before the external real-world workflow is dispatched.
select_finalists <- function() {
  fams <- t2_families()
  mc <- do.call(rbind, lapply(fams, function(f) {
    p <- file.path(Sys.getenv('T2_MC_INFERENCE_ROOT', 'artifacts/confirmatory_v2/inference'),
                   f, 'primary_inference.csv')
    if (!file.exists(p)) stop('Missing Monte Carlo inference: ', p)
    read.csv(p, stringsAsFactors = FALSE, check.names = FALSE)
  }))
  st <- do.call(rbind, lapply(fams, function(f) {
    p <- file.path(v3_root(), 'stress_inference', f, 'stress_primary.csv')
    if (!file.exists(p)) stop('Missing stress inference: ', p)
    read.csv(p, stringsAsFactors = FALSE, check.names = FALSE)
  }))
  selection <- merge(layer_table(mc, 'mc'), layer_table(st, 'stress'),
                     by = c('key', 'family', 'engine'), all = FALSE)
  if (nrow(selection) != length(fams) * 4L || anyDuplicated(selection$key))
    stop('Expected one frozen selection row for every family/engine hypothesis')
  selection$mc_stress_mse_confirmed <- selection$mc_mse_confirmed &
    selection$stress_mse_confirmed
  selection$mc_stress_q95_confirmed <- selection$mc_q95_confirmed &
    selection$stress_q95_confirmed
  selection$frozen_for_realworld <- selection$mc_stress_mse_confirmed &
    selection$mc_stress_q95_confirmed
  selection$selection_rule <- paste(
    'locked MC seed blocks 21-26 plus stress robustness;',
    'both MSE and q95 must satisfy CI and BH-FDR criteria in both analyses')
  selection$selection_role <- ifelse(selection$frozen_for_realworld,
                                     'primary_realworld_candidate',
                                     'negative_control_or_not_selected')
  root <- file.path(v3_root(), 'selection')
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  t2_write_csv(selection, file.path(root, 'frozen_family_engine_manifest.csv'))
  t2_write_csv(selection[selection$frozen_for_realworld,
                          c('family', 'engine', 'key', 'selection_rule'), drop = FALSE],
               file.path(root, 'frozen_realworld_candidates.csv'))
  writeLines(c('# T2 frozen real-world candidate manifest', '',
    paste0('- hypotheses assessed: ', nrow(selection)),
    paste0('- candidates frozen for independent real-world audit: ',
           sum(selection$frozen_for_realworld)),
    '- Seeds 21-26 are one locked synthetic confirmation panel.',
    '- The real-world layer is not run or inspected by this selection stage.'),
    file.path(root, 'selection_report.md'))
  writeLines('confirmatory_v3_selection COMPLETE', file.path(root, 'selection.status'))
  invisible(selection)
}

if (stage == 'stress_score') {
  if (!family %in% t2_families() || is.na(seed) || !seed %in% 21:26) stop('Expected FAMILY and seed 21..26')
  score_stress(family, seed)
} else if (stage == 'stress_inference') {
  if (!family %in% t2_families()) stop('Expected family')
  stress_inference(family)
} else if (stage == 'realworld_score') {
  t2_confirmatory_realworld_score('full')
} else if (stage == 'realworld_inference') {
  t2_confirmatory_realworld_inference('full')
} else if (stage == 'selection') {
  select_finalists()
} else if (stage == 'report') {
  joint_report()
}
cat('CONFIRMATORY V3', stage, family, if (is.finite(seed)) seed else '', 'COMPLETE\n')
