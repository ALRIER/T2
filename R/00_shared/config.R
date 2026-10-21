# Prospective fixed budgets; settings apply equally to GA and competitors.
ga_config <- list(
 train_n=1000L, heldout_n=c(200L,1000L,3000L),
 contamination_rates=c(0,.01,.05,.10,.20,.30),
 mad_scales=c(1.5,3,4.5,6,9,12,15,20,30),
 contamination_types=c('upper_tail','lower_tail','symmetric_t','point_mass','clustered_upper','clustered_symmetric','mixture_bimodal_near','mixture_bimodal_far'),
 population=150L, generations=80L, seeds=9L,
 training_seed_indices=0:7, heldout_seed_index=8L, bootstrap_B=500L,
 patience=10L, improvement=.001, training_fraction=.8, batch_size=32L,
 objective_names=c('mse','q95'), fdr_primary=.05, fdr_sensitivity=.10,
 mutation_rate=.15, crossover_probability=.9, evaluation_replicates=500L,
 training_bands=list(clean=0,low=c(.01,.05),intermediate=.10,high=c(.20,.30)),
 external_realworld_target='full_data_mean_proxy'
)
