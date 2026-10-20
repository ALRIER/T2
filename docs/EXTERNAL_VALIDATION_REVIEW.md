# External validation review

Reviewed source: `ALRIER/Genetic_Algorithms`, commit `8f5cfea` (shallow clone used
for review on 2026-10-20). The repository contains the validation-stage code and
the report `GA_Results/06_realworld_external_battery_40datasets/02_reports/external_realworld_results_report_V5.pdf`.

## What was actually validated

The discovery and core simulation stages use generated samples from the six
distributional families. The GA does not use empirical datasets as its population
truth. There are two separate empirical-data layers and they must not be merged.

### Monte Carlo empirical anchoring (earlier validation layer)

The auxiliary Monte Carlo validation suite has four purposes: moment fidelity,
contamination fidelity, statistical sanity, and empirical anchoring. Its empirical
anchoring layer compares the shape diagnostics of real observations with the
convex hull of the synthetic grid. It uses five anchors, one for each intended
shape family:

| ID | Dataset/input | Transformation | Matched family | Reason |
|---|---|---|---|---|
| DS1 | UCI Wine | Alcohol column | normal | Near-symmetric clean baseline |
| DS2 | UCI Forest Fires | `log(area + 1)` | lognormal | Positive right-skewed profile |
| DS3 | GBSG2 survival | Uncensored positive survival time | Weibull | Positive time-to-event profile |
| DS4 | Lexical-decision reaction times (`rtdists`/fallback) | Correct responses, cleaned to seconds | ex-Gaussian / ex-Wald | Canonical right-skewed reaction-time profile |
| DS5 | Yahoo Finance SPY | Daily log returns | heavy-tail stress profile | Fat-tailed financial returns |

This layer validates whether the simulated parameter grid covers empirical shapes;
it does not evaluate frozen GA winners.

### Final real-world external battery (later validation layer)

The empirical extension is a separate battery that evaluates frozen GA candidates
after discovery; it does not retrain, mutate, or re-optimize their weights.

The archived external registry records these primary source groups:

- 20 UCI-derived tasks from 10 source files: Wine red/white, Forest Fires,
  Abalone, Auto MPG, Parkinsons, Bike Sharing, Online News Popularity, and
  Student Math/Portuguese.
- 30 selected `Rdatasets` package/item tasks, each using an automatically chosen
  numeric variable after the source and profile filters.
- Market-return sources were present in the catalog, but the archived run marked
  them `load_failed` because the downloaded format did not match the loader; they
  are not valid primary evidence from that run.

The report describes a later expanded run with 228 loaded empirical datasets and
additional within-dataset depth probes. The registry also contains excluded,
failed, and probe rows, so its row count must not be interpreted as the number of
independent primary datasets.

## Why the design uses these datasets and controls

1. The GA searches for regime-conditional specialist estimators, so empirical
   observations are assigned a predeclared profile before any winner is counted.
2. Candidate weights are frozen for external validation. This separates discovery
   from transfer evaluation and prevents validation data from changing the model.
3. The primary comparison uses a fixed profile-specific benchmark. Oracle
   comparisons remain secondary audit rows.
4. Paired bootstrap intervals are calculated for the same gain statistic reported
   in the decision table.
5. Benjamini-Hochberg FDR is applied at dataset level. Gate rows within a dataset
   are correlated and therefore are not treated as independent discoveries.
6. Saturation caps and depth probes prevent repeated conditions from making one
   dataset count as many independent datasets.

## Consequence for T2

This review identifies the intended external sources and scientific rationale. T2
now has a separate MC anchoring adapter and shape-range check. The L1--L3
historical audit layers are integrated and pass the local smoke contract. Four
anchors are stored locally with hashes; SPY remains an external
non-redistributable input and cannot be checked into the public repository.
Before enabling full mode, T2 needs a policy-approved private-input path for
SPY and the final external-battery adapter and manifest.
Until those gates are satisfied, the fixture-only smoke run remains the only
intentionally passing real-world mode.

The current implementation therefore keeps the full real-world and stress gates
closed rather than silently substituting fixtures for empirical evidence.
