#!/usr/bin/env Rscript
# Guard the active V3 entrypoints against silent fallback to historical routines.
active <- c("scripts/v3_montecarlo_stage.R",
            "scripts/hpo_evaluate_trial.R",
            "scripts/hpo_refit_freeze.R",
            "R/01_monte_carlo/v3_generation.R")
obsolete <- c("t2_canonical_mc\\s*\\(",
              "t2_mc_seed\\s*\\(",
              "t2_mc_scenario_seed\\s*\\(",
              "build_contamination_grid\\s*\\(",
              "t2_dr_scenarios\\s*\\(",
              "t2_seed\\s*\\(")
for(file in active) {
  lines<-readLines(file,warn=FALSE)
  for(pattern in obsolete) {
    found<-grep(pattern,lines,perl=TRUE)
    if(length(found))stop(sprintf("Legacy call in %s at lines %s: %s",
         file,paste(found,collapse=","),pattern))
  }
}
for(file in active[-4L]) {
  x<-paste(readLines(file,warn=FALSE),collapse="\n")
  if(!grepl("t2_v3_generate\\s*\\(",x,perl=TRUE))
    stop("Active V3 entrypoint missing new generator: ",file)
}
cat("V3_ACTIVE_ENTRYPOINT_LEGACY_GUARD_PASS\n")
