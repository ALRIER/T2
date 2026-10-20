# T2 — estándar de ejecución reproducible

Este documento es el contrato obligatorio para cualquier equipo local, runner de GitHub Actions o instancia que ejecute el full.

## Entorno obligatorio

- R `4.3.3`.
- `statmod` `1.5.2` desde CRAN.
- `MASS` `7.3-60.0.1`.
- Paquetes base `stats`, `utils`, `methods`, `graphics`, `grDevices` y `datasets`, todos de R `4.3.3`.
- Sistema de archivos UTF-8 y ejecución desde la raíz del repositorio.
- Mismo commit de T2 antes de asignar un shard.

Las versiones están declaradas en `config/runtime_requirements.csv`. No se debe ejecutar el full si `Rscript scripts/check_environment.R` no termina con `RUNTIME CONTRACT PASS`.

## RNG y semillas

El código fija explícitamente:

```r
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
```

La unidad de reparto es el shard completo `familia × motor × semilla`. Todas las etapas de un shard deben permanecer en el mismo entorno. No se debe reanudar una etapa en otro entorno que no haya pasado el contrato.

## Instalación local

Instalar R 4.3.3 y, desde la raíz de T2:

```bash
Rscript -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/statmod/statmod_1.5.2.tar.gz", repos=NULL, type="source")'
Rscript scripts/check_environment.R
```

Después ejecutar los smoke tests:

```bash
Rscript scripts/run_all_smoke.R
```

## GitHub Actions

El workflow fija R 4.3.3, instala `statmod` 1.5.2 y ejecuta el mismo chequeo antes de cualquier stage. Un fallo del contrato detiene el job antes de consumir un shard.

## Reparto entre equipos

1. Todos hacen checkout del mismo commit.
2. Cada equipo recibe un listado único de shards.
3. Cada shard escribe únicamente en su propia carpeta bajo `artifacts/`.
4. Los checkpoints se suben con el nombre del shard; nunca se comparten rutas de escritura.
5. La integración final valida commit, entorno, hash de configuración y estado `PASS`.

El plan inicial se genera con:

```bash
Rscript scripts/generate_shard_plan.R
```

El archivo `config/worker_profiles.csv` define la concurrencia máxima, núcleos reservados, memoria mínima y límites térmicos de cada worker. La asignación inicial es deliberadamente más pequeña para Actions hasta medir un shard full; se puede cambiar mediante `T2_ACTIONS_SHARDS`, `T2_STRONG_SHARDS` y `T2_LOCAL_SHARDS`, siempre conservando 192 shards en total.

En equipos físicos se ejecuta el supervisor adaptativo:

```bash
bash scripts/run_adaptive_worker.sh physical_local full config/shard_plan.csv
bash scripts/run_adaptive_worker.sh physical_strong full config/shard_plan.csv
```

El supervisor reserva núcleos, limita la memoria disponible, observa sensores térmicos y solo aumenta la concurrencia después de lecturas estables. Al alcanzar el umbral de advertencia deja de iniciar shards; al alcanzar el umbral crítico detiene el lote de forma segura. `T2_ALLOW_NO_TEMP_SENSOR=1` solo debe usarse después de verificar manualmente la temperatura del equipo.

Ejemplo de shard:

```text
normal_ga_seed0
weibull_de_seed3
```

## Reanudación

Un checkpoint solo puede restaurarse si coinciden el commit, la configuración, la versión de R, los paquetes, el RNG y el nombre del shard. Si uno difiere, se debe iniciar el shard desde el último checkpoint compatible o volver a ejecutarlo.

## Artefactos mínimos

Cada shard debe conservar checkpoints, raw, CSV de trazabilidad, manifest, estado final y `sessionInfo()`. Los archivos se escriben bajo carpetas específicas de etapa y se someten al límite de tamaño definido por el contrato de artefactos.

## Prueba de dos entornos

Antes del full, ejecutar una misma semilla en dos equipos y comparar hashes de configuración, manifest y estados. Se aceptan pequeñas diferencias numéricas solo si están dentro de la tolerancia documentada; no se acepta una diferencia de estructura, filas, semillas o estado de checkpoint.
