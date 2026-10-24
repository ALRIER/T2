#!/usr/bin/env Rscript
root <- 'artifacts/discovery_v3'
families <- c('normal','lognormal','weibull','invgauss','exgaussian','exwald')
rows <- list(); k<-0L
for(family in families)for(seed in 0:9) {
  p <- file.path(root,family,sprintf('seed%02d',seed),'discovery.rds')
  if(!file.exists(p)) stop('Missing discovery artifact ',p)
  fit <- readRDS(p)
  for(engine in names(fit$engines)) {
    z <- fit$engines[[engine]]
    O <- as.matrix(z$objectives)
    W <- as.matrix(z$weights)
    if(ncol(O)!=2L || nrow(O)!=ncol(W) || nrow(W)!=26L ||
       any(!is.finite(O)) || any(!is.finite(W)))stop('Invalid model matrix')
    ix_mse<-which.min(O[,1L]);ix_q95<-which.min(O[,2L])
    scale <- pmax(colMeans(abs(O)),1e-12)
    ix_balanced<-which.min(rowSums(sweep(O,2L,scale,'/')))
    for(goal in c('mse','q95','balanced')) {
      idx <- switch(goal,mse=ix_mse,q95=ix_q95,balanced=ix_balanced)
      k<-k+1L
      rows[[k]]<-data.frame(family=family,seed=seed,engine=engine,
                            goal=goal,mse=O[idx,1L],q95=O[idx,2L],
                            candidate_index=idx,
                            weights=paste(sprintf('%.9f',W[,idx]),collapse=';'))
    }
  }
}
out <- do.call(rbind,rows)
dir.create('artifacts/discovery_analysis',recursive=TRUE,showWarnings=FALSE)
write.csv(out,'artifacts/discovery_analysis/training_candidates.csv',row.names=FALSE)
agg <- aggregate(cbind(mse,q95)~family+engine+goal,out,mean)
write.csv(agg,'artifacts/discovery_analysis/training_summary.csv',row.names=FALSE)
cat('V3_DISCOVERY_WINNER_REPORT_PASS',nrow(out),'rows\n')
