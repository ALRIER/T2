root <- tempfile('t2-resume-')
dir.create(root, recursive = TRUE)
old <- Sys.getenv('T2_OUTPUT_ROOT', unset = NA_character_)
on.exit({
  if (is.na(old)) Sys.unsetenv('T2_OUTPUT_ROOT') else Sys.setenv(T2_OUTPUT_ROOT = old)
  unlink(root, recursive = TRUE)
}, add = TRUE)
Sys.setenv(T2_OUTPUT_ROOT = root, T2_RESUME = '0')
status1 <- system2('Rscript', c('scripts/run_stage.R', 'datasets', 'resume_contract',
                                'smoke', 'normal', '0', 'all'))
stopifnot(status1 == 0L)
source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
stopifnot(t2_stage_complete('resume_contract', 'datasets'))
Sys.setenv(T2_RESUME = '1')
status2 <- system2('Rscript', c('scripts/run_stage.R', 'datasets', 'resume_contract',
                                'smoke', 'normal', '0', 'all'), stdout = TRUE)
stopifnot(!inherits(status2, 'try-error'), any(grepl('RESUME SKIP', status2)))
cat('RESUME CONTRACT PASS\n')
