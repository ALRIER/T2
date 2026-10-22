# 04 — Validation and frozen portfolio confirmation

All W* vectors are scored without retraining.  The module contains held-out,
stress and source-to-target portfolio generalization.  MSE and q95 are tested
separately; a joint result is a descriptive Pareto label, never an exclusion
filter.  BH-FDR is applied only after all planned shard results are assembled.

Main entry point: `scripts/confirmatory_portfolio_generalization.R`.
Workflow: `.github/workflows/confirmatory-portfolio-generalization.yml`.
