source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
m <- t2_realworld_manifest()
checked <- t2_realworld_validate_manifest(m, 'smoke')
stopifnot(nrow(checked) == nrow(m), all(nzchar(checked$sha256_actual)))
full_checked <- t2_realworld_validate_manifest(m, 'full')
stopifnot(nrow(full_checked) == 50L,
          all(nzchar(full_checked$sha256_actual)))
cat('REALWORLD MANIFEST CONTRACT PASS\n')
