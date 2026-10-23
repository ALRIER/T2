#!/usr/bin/env Rscript
source("R/00_shared/load_all.R");t2_load(".")
W<-matrix(0,26,3);W[1,1]<-1;W[2,2]<-1;W[3,3]<-1
O<-rbind(c(2,10),c(5,5),c(10,2))
out<-t2_select_three_candidates(W,O)
stopifnot(identical(out$role,c("both","mse","q95")),
          out$candidate_index[out$role=="mse"]==1L,
          out$candidate_index[out$role=="q95"]==3L,
          out$candidate_index[out$role=="both"]==2L)
# A single point may fulfill all roles, without implying independent winners.
identical_o<-matrix(rep(c(1,1),3),ncol=2,byrow=TRUE)
z<-t2_select_three_candidates(W,identical_o)
stopifnot(nrow(z)==3L,identical(z$role,c("both","mse","q95")))
stopifnot(!("winner"%in%names(out)),!("winner"%in%names(z)))
cat("THREE_CANDIDATES_CONTRACT_PASS\n")
