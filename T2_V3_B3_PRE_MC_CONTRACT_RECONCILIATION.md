# T2_V3_B3 — Reconciliación de contratos anteriores al cierre de Monte Carlo

**Estado:** auditoría del código y de la historia de commits. Identificación única: Prueba T2 versión 3 B3. Este documento no modifica los resultados congelados.

| Requisito acordado | Antecedente rastreado | Contrato B3 y situación |
|---|---|---|
| 240 particiones independientes, 6 familias, 500 réplicas, 121 escenarios, N por rol | Monte Carlo Production Only; corrección de permisos de SHA256SUMS `5f234b0` | `R/00_shared/config.R`, `R/00_shared/v3_scientific_adapter.R`; no volver a generar matrices |
| Discovery 0:9; Held-out 10:14; Stress 15:19 | Partición V3 congelada antes del fin de Monte Carlo | Validación de roles y N en `t2_v3_block_dir()`; jamás reutilizar el mismo bloque como muestra externa |
| Archivos por escenario y carga mínima | Adaptador de lectura `b185e1139`; carga selectiva `8ee138433` | `t2_v3_read_scenario()` y evaluación incremental en `scripts/v3_confirmatory_inference.R` |
| Trabajos independientes, ≤4 en paralelo, sin compartición de RAM | Producción Monte Carlo dividida en jobs | `t2-v3-b3-heldout-stress-full.yml`; workflows legacy reconducidos al motor B3 |
| Reconciliación, integridad de fuentes, hashes | Error original permisos del manifiesto de hashes corregido en `5f234b0` | `t2_b3_inputs_manifest()` y hashes en `t2_v3_b3_resources.R` (`8662c54d0`). **Pendiente:** respaldo externo después de expirar artefactos de Actions |
| Guardas RAM, cgroup, limpieza y resultados incrementales | Diseño acordado antes y durante Monte Carlo; implementación B3 `8662c54d0` | `t2_b3_ram_guard()` y `memory_T2_V3_B3.csv`, escritura incremental, `rm()`/`gc()` |
| 26 controles originales + cuatro candidatos congelados | Comparación científica integral; commit `6bb2a7743` | En Held-out y Stress `scripts/v3_confirmatory_inference.R`; no alterar W |
| Bootstrap pareado, MSE/q95, IC, BH-FDR y taxonomía existente | Protocolos `confirmatory_protocol.csv` y `confirmatory_v3_protocol.csv`; commits `9d99c72a8`, `71d9d0294` | `R/00_shared/v3_inference.R`; **pendiente:** verificación exhaustiva de validez para inferencia múltiple con dependencia entre escenarios |
| Falsos positivos mediante nulas | Diseño confirmatorio previo | `t2_v3_null_fpr()` implementa diagnóstico de intercambio pareado. **No equivale a certificación integral de FPR**; se debe calibrar el procedimiento de extremo a extremo, incluida selección |
| External Real World: procedencia y muestras de padres independientes | Auditoría de datasets + recuperación de scoring heredado | `t2_v3_b3_realworld_scoring.R` y `t2_v3_b3_realworld_parent_inference.R`; objetivo = proxy de media empírica, no verdad poblacional |
| Igualdad de presupuesto, reproducibilidad RNG, recuperación de checkpoints | Auditoría del 19-oct: contratos de ejecución y no fuga | **Pendiente de certificar:** reproducibilidad exacta con distintos workers, reinicio de cálculos parciales y pruebas integrales |
| Versión inconfundible de resultados | Denominación acordada T2 V3 B3 | Manifiesto `T2_V3_B3_VERSION_MANIFEST.md`; ficheros de salida con sufijo `_T2_V3_B3` y mapa de correspondencia |

## Importante: protocolos archivados versus V3 actual

El archivo `config/confirmatory_v3_protocol.csv` registra semillas 21:26 de una capa confirmatoria anterior. **No debe sobreescribir** la separación vigente de Monte Carlo V3 (0:9 / 10:14 / 15:19). Cualquier informe debe identificar explícitamente cuál de estas dos capas está utilizando.

## Historia de integración auditada

- `5f234b0`: reparación de integridad de artefactos de Monte Carlo.
- `b185e1139` y `8ee138433`: flujo de escenarios de V3 y optimización de carga.
- `8662c54d0`: guardas RAM y manifiestos.
- `c4280a997`: streaming de inferencia de Held-out/Stress.
- `6bb2a7743`: panel completo de benchmarks.
- `71d9d0294`, `9d99c72a8`: referencia fijada y taxonomía BH-FDR.
- `670613a4d`, `45630d4fa`: workflows heredados reconducidos al ejecutor B3.
- `9316245a9`: control estático de contratos previo a otra producción.

## Bloqueo de certificación

Un job exitoso valida su ejecución, **no** certifica todos los contratos experimentales. Antes de etiquetar «B3 completa» se exige prueba de paridad numérica, calibración de FPR del procedimiento completo, cobertura de Real World, control de fuga, verificación del protocolo y auditoría de memoria. Mantener resultados históricos de solo MSE/q95 marcados como parciales.
