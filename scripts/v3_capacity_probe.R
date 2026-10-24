#!/usr/bin/env Rscript
source("R/00_shared/load_all.R");t2_load(".")
source("R/00_shared/pipeline.R")
source("R/01_monte_carlo/v3_generation.R")
before<-proc.time()[["elapsed"]]
z<-t2_v3_generate("discovery","normal",0L,1000L,R=500L,n_scenarios=8L,
 root="artifacts/v3_full_smoke/load_data")
elapsed<-proc.time()[["elapsed"]]-before
warnings_file<-file.path("artifacts/v3_full_smoke/load_data",
 "v3_real26_seedplan20_foldisolated","discovery","normal","seed00","n1000_r500","numeric_warnings.csv")
warnings_count<-if(file.exists(warnings_file))nrow(read.csv(warnings_file)) else 0L
dir.create("artifacts/v3_full_smoke",recursive=TRUE,showWarnings=FALSE)
write.csv(data.frame(n=1000L,reps=500L,scenarios=nrow(z$grid),
 elapsed_seconds=elapsed,numeric_warning_count=warnings_count),
 "artifacts/v3_full_smoke/capacity.csv",row.names=FALSE)
if(warnings_count>0L)cat("NUMERIC_WARNING_REVIEW_REQUIRED ",warnings_count,"\n")
cat("V3_CAPACITY_PROBE_COMPLETE\n")
