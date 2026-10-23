#!/usr/bin/env Rscript
# Outcome-blind selection of 500 independent parent datasets for RW-V2.
# No model score, error, p-value, or winner field is read by this script.
args <- commandArgs(trailingOnly=TRUE)
input <- if(length(args)) args[[1L]] else Sys.getenv('RW2_PROFILE_REGISTRY')
if(!nzchar(input) || !file.exists(input)) stop('Provide profile_registry.csv')
out <- if(length(args)>1L) args[[2L]] else 'artifacts/realworld_regime_matched_v2/frozen_manifest'
dir.create(out, recursive=TRUE, showWarnings=FALSE)
x <- read.csv(input, stringsAsFactors=FALSE, check.names=FALSE)
required <- c('dataset_id','parent_dataset_id','domain','source_url','empirical_profile','load_ok','raw_sha256')
if(!all(required %in% names(x))) stop('Profile registry has an invalid contract')
x <- x[x$load_ok %in% TRUE & !duplicated(x$parent_dataset_id),,drop=FALSE]
x$source_group <- ifelse(grepl('financial', x$domain, ignore.case=TRUE), 'financial',
  ifelse(grepl('rdatasets', x$domain, ignore.case=TRUE), 'rdatasets',
    ifelse(grepl('^UCI_', x$dataset_id), 'uci', 'other')))
# Every technically valid, independent parent is retained.  Balance is a
# reporting/weighting attribute, never an outcome-dependent exclusion rule.
selected <- x[order(x$source_group,x$empirical_profile,x$domain,x$dataset_id),,drop=FALSE]
if(!nrow(selected) || anyDuplicated(selected$parent_dataset_id)) stop('Frozen selection contract failed')
quota <- as.data.frame.matrix(table(selected$empirical_profile, selected$source_group))
quota$empirical_profile <- rownames(quota); rownames(quota) <- NULL
selected$selection_profile <- selected$empirical_profile
selected$selection_source_group <- selected$source_group
selected$selection_rule <- 'v2_all_technically_valid_independent_parents_v1'
selected$manifest_role <- 'independent_parent_dataset'
write.csv(selected,file.path(out,'realworld_v2_500_parent_manifest.csv'),row.names=FALSE)
write.csv(quota,file.path(out,'selection_quotas.csv'),row.names=FALSE)
writeLines(c('REALWORLD_V2_MANIFEST_COMPLETE',paste0('target_parent_datasets=',nrow(selected)),
 'selection uses only provenance and pre-score structural profiles; no performance field was accessed'),file.path(out,'manifest.status'))
cat('FROZEN REALWORLD V2 MANIFEST',nrow(selected),'parents\n')
