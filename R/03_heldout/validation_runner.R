t2_run_datasets <- function(mode,shard) {
 manifest <- file.path('config','public_datasets.csv')
 if (!file.exists(manifest)) stop('Frozen public dataset manifest is missing')
 tab <- read.csv(manifest,stringsAsFactors=FALSE)
 if (!all(c('dataset_id','path','sha256','license') %in% names(tab))) stop('Incomplete dataset manifest')
 if (!nrow(tab)) stop('No datasets registered; cannot pass')
 if (mode=='full' && any(grepl('fixture|nonredistributable|review|pending|unknown',tab$license,ignore.case=TRUE)))
   stop('Full runs require reviewed redistributable public inputs')
 if (any(!nzchar(tab$license))) stop('Dataset license not documented')
 if (any(!file.exists(tab$path))) stop('Dataset cache is incomplete')
 hashes <- unname(tools::md5sum(tab$path))
 if (anyNA(hashes)) stop('Cannot calculate dataset digests')
 if (requireNamespace('digest',quietly=TRUE)) {
  actual <- vapply(tab$path,digest::digest,character(1),algo='sha256',file=TRUE)
 } else {
  actual <- vapply(tab$path,function(f) {
   z<-suppressWarnings(system2('sha256sum',shQuote(f),stdout=TRUE))
   if(length(z)!=1L)stop('SHA256 unavailable');strsplit(z,' ')[[1]][1]
  },character(1))
 }
 if (any(tolower(actual)!=tolower(tab$sha256))) stop('Dataset integrity mismatch')
 list(status='PASS',manifest=tab,sha256=actual,fixture=identical(mode,'smoke'))
}

t2_run_mc_validation <- function(mode,shard) {
 d<-t2_require(shard,'datasets')
 if(!identical(d$status,'PASS'))stop('Datasets did not pass')
 seed<-t2_seed(shard,730L);set.seed(seed)
 n <- if(mode=='smoke') 1500L else 20000L
 x<-generate_population('normal',n,t2_params('normal'))
 l1 <- is.finite(mean(x)) && abs(mean(x)) < 5/sqrt(n) &&
       abs(sd(x)-1) < 5/sqrt(2*n)
 contaminated<-inject_outliers_realistic(x,contamination_rate=.2,outlier_scale_mad=9,type='upper_tail')
 l2 <- length(contaminated)==n && all(is.finite(contaminated)) &&
       abs(mean(contaminated)-mean(x))>1e-3
 m <- if(mode=='smoke') 120L else 1500L
 z<-replicate(m,{a<-rnorm(200);c(mean(a)^2,median(a)^2)})
 l3 <- mean(z[1,]) < mean(z[2,])
 l4 <- nrow(d$manifest)>=1L && all(file.exists(d$manifest$path))
 results<-data.frame(layer=c('L1_interface','L2_interface','L3_interface','L4_manifest'),
                    status=ifelse(c(l1,l2,l3,l4),'PASS','FAIL'),
                    stringsAsFactors=FALSE)
 audits <- t2_run_integrated_mc_audits(mode, shard)
 results <- rbind(results, audits$summary)
 overall<-if(all(results$status=='PASS')) 'PASS' else 'FAIL'
  anchor <- t2_run_mc_empirical_anchoring(mode, shard)
  if (mode == 'full' && !identical(anchor$status, 'PASS')) overall <- 'FAIL'
  if (mode == 'smoke' && identical(anchor$status, 'SKIPPED')) overall <-
    if (audits$status == 'PASS' && all(results$status == 'PASS')) 'PASS' else 'FAIL'
  list(status=overall, layers=results, empirical_anchor=anchor$status,
       empirical_manifest=anchor$manifest,
       results=c(audits$results, list(empirical_anchor=if (!is.null(anchor$results)) anchor$results else
                      data.frame(status=anchor$status, reason=anchor$reason))),
       seed=seed, scientific_scope=if(mode=='smoke')
   'Integrated historical audit smoke plus interface checks; empirical anchoring is not executed in smoke' else
   'Integrated historical audits plus empirical shape anchoring; final real-world validation remains separate',
   integrated_historical_audits=audits$status,
   legacy_four_layer_certified=isTRUE(mode == 'full' && audits$status == 'PASS' && anchor$status == 'PASS'))
}

t2_run_heldout <- function(discovery,mode,shard,family='normal') {
 t2_validate_W(discovery$models)
 cfg<-discovery$config; replications<-if(mode=='smoke')30L else cfg$evaluation_replicates
 n_values<-if(mode=='smoke')c(200L,1000L,3000L) else cfg$heldout_n
 by_n<-lapply(seq_along(n_values),function(i){
  n<-n_values[i];s<-t2_canonical_mc(mode, family, t2_heldout_seed_index(), n, replications)$scenarios
  per_sc<-lapply(s,function(z){scores<-score_model_set(z$T,discovery$models,z$target);scores$scenario_id<-z$scenario_id;scores$sample_n<-n;scores})
  do.call(rbind,per_sc)
 })
 lapply(by_n, t2_validate_scores)
 audit <- t2_heldout_independence_audit(discovery, mode, shard, family, n_values)
 list(scores=do.call(rbind,by_n),models=discovery$models,stage='heldout',fresh_rng=TRUE,
      independence_audit=audit, budget_parity=t2_budget_parity_audit(discovery))
}

t2_run_stress <- function(discovery,mode,shard,family='normal') {
 t2_validate_W(discovery$models)
 stress_mode <- if (mode == 'full') 'full' else 'smoke'
 stress_n <- as.integer(Sys.getenv('T2_STRESS_SAMPLE_N', unset=if(mode=='full') '1000' else '200'))
 stress_R <- as.integer(Sys.getenv('T2_STRESS_REPS', unset=if(mode=='full') '250' else '30'))
 if (!is.finite(stress_n) || stress_n < 20L || !is.finite(stress_R) || stress_R < 5L)
   stop('Invalid stress runtime configuration')
 stress_path <- t2_mc_path(stress_mode, family, t2_heldout_seed_index(), stress_n, stress_R)
 if (mode == 'full' && identical(Sys.getenv('T2_REQUIRE_CANONICAL_STRESS', '0'), '1') &&
     !file.exists(stress_path)) {
   stop('Canonical stress block is missing: ', stress_path,
        '; refusing to regenerate it inside every model shard')
 }
 x<-t2_canonical_mc(stress_mode, family, t2_heldout_seed_index(), stress_n, stress_R)
 result<-do.call(rbind,lapply(x$scenarios,function(s){z<-score_model_set(s$T,discovery$models,s$target);z$scenario_id<-s$scenario_id;z}))
 t2_validate_scores(result)
 list(scores=result,stage='stress',fixture=identical(mode, 'smoke'),stress_config=list(sample_n=stress_n,
      replications=stress_R,scenario_count=length(x$scenarios),family=family))
}
