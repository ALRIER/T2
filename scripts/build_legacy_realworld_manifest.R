#!/usr/bin/env Rscript
# Convert the acquired historical public-battery registry to portable paths.
source('R/00_shared/load_all.R'); t2_load('.')
infile <- file.path('config','public_datasets_legacy.csv')
if (!file.exists(infile)) stop('Missing local legacy acquisition manifest')
x <- read.csv(infile, stringsAsFactors=FALSE, check.names=FALSE)
req <- c('dataset_id','path','sha256','license','variable','transform','source_url','source_sha256','domain','family_hint')
if (!all(req %in% names(x))) stop('Legacy source manifest lacks required columns')
x$parent_dataset_id <- paste0('parent_',substr(x$source_sha256,1L,16L))
x$source_group <- sub('^([A-Za-z]+).*','\\1',x$dataset_id)
x$path <- sub('^/home/alrier/T2/','',x$path)
x <- x[,c('dataset_id','parent_dataset_id','path','sha256','license','variable','transform','source_url','source_sha256','domain','family_hint','source_group')]
t2_write_csv(x,file.path('config','legacy_realworld_t2_manifest.csv'))
cat('Wrote',nrow(x),'rows and',length(unique(x$parent_dataset_id)),'parent datasets\n')
