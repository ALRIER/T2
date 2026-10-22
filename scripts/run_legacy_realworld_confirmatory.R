#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly=TRUE)
stage <- if(length(args)) args[[1L]] else stop('Usage: score|inference [smoke|full]')
mode <- if(length(args)>1L) args[[2L]] else 'smoke'
if(!stage %in% c('score','inference') || !mode %in% c('smoke','full')) stop('Invalid arguments')
source('R/00_shared/load_all.R'); t2_load('.'); source('R/00_shared/pipeline.R'); t2_check_runtime('.',strict=TRUE)
if(stage=='score') t2_legacy_rw_score(mode) else t2_legacy_rw_inference(mode)
cat('LEGACY_REALWORLD',stage,mode,'COMPLETE\n')
