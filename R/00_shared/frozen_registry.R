t2_models <- function(d) {
 mods<-reference_model_set()
 for(engine in names(d)) {
  result<-d[[engine]]; ix<-which.min(rowSums(sweep(result$objectives,2,pmax(colMeans(abs(result$objectives)),1e-12),'/')))
  mods[[length(mods)+1L]]<-new_frozen_model(engine,weights=result$weights[,ix],family=engine)
 }
 mods
}
