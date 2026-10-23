#!/usr/bin/env Rscript
source("R/00_shared/load_all.R");t2_load(".")
t2_assert_seed_plan_v3()
roles<-rep(c("discovery","heldout","stress"),c(10,5,5))
for(i in 0:19) stopifnot(i %in% t2_seed_plan_v3[[roles[i+1L]]])
for(f in c("normal","exwald")) {
 keys<-vapply(0:19,function(i)t2_seed_for_v3(roles[i+1L],f,i,1000L),integer(1))
 stopifnot(all(is.finite(keys)),length(unique(keys))==20L)
}
stopifnot(identical(t2_seed_plan_v3$realworld_n,c(200L,1000L)))
cat("V3_SEED_PLAN_CONTRACT_PASS\n")

# V3 stage contract: ten discovery seeds, five confirmation, five stress.
stopifnot(identical(t2_v3_indices("discovery"),0:9),
          identical(t2_v3_indices("heldout"),10:14),
          identical(t2_v3_indices("stress"),15:19),
          identical(t2_v3_sample_sizes("discovery"),1000L),
          identical(t2_v3_sample_sizes("heldout"),c(200L,1000L,3000L)),
          identical(t2_v3_sample_sizes("stress"),c(200L,1000L,3000L)),
          identical(t2_v3_sample_sizes("realworld"),c(200L,1000L)),
          t2_v3_expected_role_entries()==720L)
