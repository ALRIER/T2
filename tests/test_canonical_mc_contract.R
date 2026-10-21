source('R/00_shared/load_all.R'); t2_load('.')
source('R/00_shared/pipeline.R')
root <- tempfile('t2-canonical-')
dir.create(root, recursive = TRUE)
old <- Sys.getenv('T2_CANONICAL_MC_ROOT', unset = NA_character_)
Sys.setenv(T2_CANONICAL_MC_ROOT = root)
on.exit(if (is.na(old)) Sys.unsetenv('T2_CANONICAL_MC_ROOT') else Sys.setenv(T2_CANONICAL_MC_ROOT = old), add = TRUE)
a <- t2_canonical_mc('smoke', 'normal', 0L, 30L, 4L)
b <- t2_canonical_mc('smoke', 'normal', 0L, 30L, 4L)
h <- t2_canonical_mc('smoke', 'normal', 8L, 30L, 4L)
final_path <- t2_mc_path('smoke', 'normal', 0L, 30L, 4L)
unlink(final_path)
resumed <- t2_canonical_mc('smoke', 'normal', 0L, 30L, 4L)
stopifnot(isTRUE(a$generated_once), identical(a$seed, b$seed),
          a$seed_index == 0L, h$seed_index == 8L, !identical(a$seed, h$seed),
          identical(a$scenarios, resumed$scenarios), file.exists(final_path),
          file.exists(paste0(final_path, '.progress.rds')),
          file.exists(file.path(paste0(final_path, '.parts'), 'base_samples.rds')),
          length(grep('^scenario_[0-9]+\\.rds$',
                      list.files(paste0(final_path, '.parts')))) == 4L)
cat('CANONICAL MC CONTRACT PASS\n')
