# Prueba T2 versión 3 B3 — Implementación de Held-out, Stress y Real World

**Versión identificadora:** `T2_V3_B3`. Los artefactos originales permanecen inmutables.

## Workflows principales
- Held-out y Stress, 180 particiones independientes: `.github/workflows/t2-v3-b3-heldout-stress-full.yml`.
- Real World, una familia por lote auditado, seis familias y agregación por dataset padre: `.github/workflows/t2-v3-b3-realworld-full.yml`.
- Pruebas reducidas: `t2-v3-b3-heldout-stress-verify.yml`, `t2-v3-b3-realworld-scoring-smoke.yml` y `t2-v3-b3-realworld-parent-smoke.yml`.

**Seguridad operativa:** las producciones completas son `workflow_dispatch`; no se activan automáticamente al subir cambios. Se descargan las fuentes congeladas de Monte Carlo (run 40053612297), Discovery (40132811105) y auditoría externa (40142001843), sin recalcular ni sobreescribir W.

## Arquitectura de memoria
1. RDS científicos se leen por escenario o dataset, en particiones independientes.
2. Un job evalúa una familia y un lote; los modelos congelados se reutilizan.
3. Los resultados se escriben progresivamente por escenario o dataset.
4. Objetos temporales se liberan entre semillas y bloques; GC periódica.
5. `T2_B3_RAM_LIMIT_MB` (6000 MB por defecto) controla el consumo observable; el módulo registra memoria actual y pico cgroup.
6. Los hashes y tamaños de insumos se conservan en `dependencies_T2_V3_B3.csv`.
7. El reporte Real World consolida los scores **archivo por archivo**, evitando reunir todas las matrices en RAM.

## Estadística
- 26 benchmarks originales y cuatro candidatos optimizados de cada semilla congelada.
- MSE y q95 sobre errores cuadráticos con réplicas emparejadas.
- Intervalos percentiles por bootstrap pareado usando los mismos índices para ambas métricas.
- Prueba t pareada unilateral para MSE; aproximación normal con error estándar bootstrap para q95.
- Corrección BH-FDR al 5 % conforme a la taxonomía establecida; corrección Holm publicada también.
- Etiquetas existentes: `mse_and_q95_bh_fdr`, `mse_only_bh_fdr`, `q95_only_bh_fdr`, `no_supported_gain`.
- Simulación diagnóstica de falsos positivos bajo intercambiabilidad pareada para los paneles simulados; diagnóstico de simetría de signos en padres Real World.

## Precauciones científicas explícitas
- La calibración por intercambio es válida bajo **su hipótesis nula de intercambiabilidad**, y no demuestra por sí sola el error tipo I del procedimiento global de selección.
- En Real World, la media de la serie empírica completa o de su profundidad es una **aproximación del objetivo**, no un valor poblacional verdadero.
- Las inferencias Real World se agregan por dataset padre; las distintas profundidades, tamaños muestrales y semillas no cuentan como observaciones externas independientes.
- El estado `Success` de un smoke test verifica la interfaz y ejecución de las comprobaciones probadas, no sustituye la auditoría de todos los resultados finales.
- No afirmar que la producción completa está terminada hasta validar todos los jobs y artefactos publicados.

## Fases congeladas
Los 240 jobs de Monte Carlo y los 60 entrenamientos Discovery permanecen como fuentes de solo lectura. Los 90 jobs previos de Held-out y 90 de Stress continúan disponibles como resultados descriptivos; las nuevas pruebas B3 son complementos inferenciales.
