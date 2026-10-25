# Prueba T2 — Versión 3 B3
**ID canónico:** `T2_V3_B3`  
**Nombre visible obligatorio:** `Prueba T2 versión 3 B3`

## Regla única de nombres
Todas las **salidas nuevas** utilizan el sufijo `_T2_V3_B3` antes de la extensión:
- `discovery_T2_V3_B3.rds`
- `manifest_T2_V3_B3.csv`
- `training_diagnostics_T2_V3_B3.csv`
- `null_diagnostics_T2_V3_B3.csv`
- `weights_by_component_T2_V3_B3.csv`
- `training_candidates_T2_V3_B3.csv`
- `component_weight_stability_T2_V3_B3.csv`
- `scores_T2_V3_B3.csv`
- `paired_inference_T2_V3_B3.csv`
- `null_calibration_T2_V3_B3.csv`
- `profiles_T2_V3_B3.csv`

Cada directorio de salida nuevo contiene `T2_V3_B3_file_map.csv`, que documenta la correspondencia entre nombres de compatibilidad y nombres B3, con hash de cada archivo.

## Scripts y workflows incluidos en esta versión
Los scripts y las rutas de workflows existentes **mantienen sus nombres técnicos** porque están referenciados desde GitHub Actions. Su pertenencia a la prueba B3 se fija mediante este manifiesto. Renombrarlos unilateralmente rompería rutas de ejecución y dependencias.

| Etapa | Script | Workflow |
|---|---|---|
| Discovery training | `scripts/v3_discovery_production.R` | `.github/workflows/v3-discovery-production.yml` |
| Discovery diagnostics | `scripts/v3_discovery_posthoc_audit.R` | `.github/workflows/v3-discovery-complete-diagnostics.yml` |
| Discovery ranking | `scripts/v3_discovery_winner_report.R` | `.github/workflows/v3-discovery-candidate-report.yml` |
| Held-out | `scripts/v3_heldout_frozen_production.R` | `.github/workflows/v3-heldout-production.yml` |
| Stress | `scripts/v3_stress_frozen_production.R` | `.github/workflows/v3-stress-production.yml` |
| Held-out/Stress inference | `scripts/v3_confirmatory_inference.R` | `.github/workflows/v3-inference-audit-smoke.yml` |
| Real World audit | `scripts/realworld_v2_catalog.R` | `.github/workflows/v3-realworld-dataset-audit.yml` |

## Integridad y versiones anteriores
**Prohibido sobrescribir o renombrar los RDS y resultados científicos congelados** de Monte Carlo y Discovery. Las copias B3 son alias adicionales y no una nueva corrida. Los runs previos permanecen bajo sus nombres históricos y se vinculan desde los manifiestos.
**Estado:** adopción de nomenclatura de salidas B3 implementada en los scripts listados. Las corridas anteriores no se han renombrado retroactivamente. La validación de las próximas ejecuciones sigue pendiente.
