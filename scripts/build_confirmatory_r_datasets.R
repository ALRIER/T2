#!/usr/bin/env Rscript

# Materialize a predeclared, independent external panel from R's datasets
# package.  The panel is fixed before scoring and is intentionally one parent
# object per dataset_id: no second variable from the same parent is admitted.

repo_root <- normalizePath('.', winslash = '/', mustWork = TRUE)
raw_root <- file.path(repo_root, 'data', 'confirmatory', 'realworld', 'raw')
processed_root <- file.path(repo_root, 'data', 'confirmatory', 'realworld', 'processed')
manifest_path <- file.path(repo_root, 'config', 'confirmatory_public_datasets.csv')
dir.create(raw_root, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_root, recursive = TRUE, showWarnings = FALSE)

get_dataset <- function(name) {
  e <- new.env(parent = emptyenv())
  utils::data(list = name, package = 'datasets', envir = e)
  if (!exists(name, envir = e, inherits = FALSE))
    stop('R datasets object was not found: ', name)
  get(name, envir = e, inherits = FALSE)
}

spec <- function(dataset_id, source_object, variable, domain, extract) {
  list(dataset_id = dataset_id, source_object = source_object, variable = variable,
       domain = domain, family_hint = 'all', independence_group = dataset_id,
       extract = extract)
}

# These are fixed parent objects from the version-pinned base R datasets
# package.  Their family_hint is deliberately "all": every frozen family is
# evaluated on every parent dataset in the confirmatory analysis.
panel <- list(
  spec('rds_airquality_ozone', 'airquality', 'value', 'environment',
       function() get_dataset('airquality')$Ozone),
  spec('rds_cars_distance', 'cars', 'value', 'transport',
       function() get_dataset('cars')$dist),
  spec('rds_faithful_eruptions', 'faithful', 'value', 'natural_process',
       function() get_dataset('faithful')$eruptions),
  spec('rds_iris_sepal_length', 'iris', 'value', 'biology',
       function() get_dataset('iris')$Sepal.Length),
  spec('rds_mtcars_mpg', 'mtcars', 'value', 'transport',
       function() get_dataset('mtcars')$mpg),
  spec('rds_quakes_magnitude', 'quakes', 'value', 'geophysics',
       function() get_dataset('quakes')$mag),
  spec('rds_usarrests_murder', 'USArrests', 'value', 'public_health',
       function() get_dataset('USArrests')$Murder),
  spec('rds_rock_area', 'rock', 'value', 'geology',
       function() get_dataset('rock')$area),
  spec('rds_nile_flow', 'Nile', 'value', 'hydrology',
       function() as.numeric(get_dataset('Nile'))),
  spec('rds_precipitation', 'precip', 'value', 'climate',
       function() as.numeric(get_dataset('precip'))),
  spec('rds_co2_uptake', 'CO2', 'value', 'biology',
       function() get_dataset('CO2')$uptake),
  spec('rds_nhtemp', 'nhtemp', 'value', 'climate',
       function() as.numeric(get_dataset('nhtemp'))),
  spec('rds_eustockmarkets_dax', 'EuStockMarkets', 'value', 'finance',
       function() get_dataset('EuStockMarkets')[, 'DAX']),
  spec('rds_chickweight', 'ChickWeight', 'value', 'biology',
       function() get_dataset('ChickWeight')$weight),
  spec('rds_dnase_density', 'DNase', 'value', 'biochemistry',
       function() get_dataset('DNase')$density),
  spec('rds_orange_circumference', 'Orange', 'value', 'biology',
       function() get_dataset('Orange')$circumference),
  spec('rds_puromycin_rate', 'Puromycin', 'value', 'biochemistry',
       function() get_dataset('Puromycin')$rate),
  spec('rds_lakehuron_level', 'LakeHuron', 'value', 'hydrology',
       function() as.numeric(get_dataset('LakeHuron'))),
  spec('rds_lifecycle_savings', 'LifeCycleSavings', 'value', 'economics',
       function() get_dataset('LifeCycleSavings')$sr),
  spec('rds_volcano_elevation', 'volcano', 'value', 'geology',
       function() as.vector(get_dataset('volcano')))
)

sha256 <- function(path) {
  if (requireNamespace('digest', quietly = TRUE))
    return(digest::digest(path, algo = 'sha256', file = TRUE))
  z <- suppressWarnings(system2('sha256sum', shQuote(path), stdout = TRUE))
  if (length(z) != 1L) stop('sha256sum unavailable for ', path)
  strsplit(z, '\\s+')[[1L]][1L]
}

source_url <- paste0(
  'https://stat.ethz.ch/R-manual/R-devel/library/datasets/html/',
  'datasets-package.html')
rows <- vector('list', length(panel))
for (i in seq_along(panel)) {
  s <- panel[[i]]
  x <- suppressWarnings(as.numeric(s$extract()))
  x <- x[is.finite(x)]
  if (length(x) < 20L || length(unique(x)) < 2L)
    stop('Confirmatory R dataset is too small or constant: ', s$dataset_id)
  raw_path <- file.path(raw_root, paste0(s$dataset_id, '.csv'))
  processed_path <- file.path(processed_root, paste0(s$dataset_id, '.csv'))
  # The raw export is a lossless numeric materialization of the pinned R
  # object.  The processed export is the exact input consumed by the adapter;
  # both are retained for auditability and checksum verification.
  tab <- data.frame(value = x)
  utils::write.csv(tab, raw_path, row.names = FALSE, quote = TRUE)
  utils::write.csv(tab, processed_path, row.names = FALSE, quote = TRUE)
  rows[[i]] <- data.frame(
    dataset_id = s$dataset_id,
    path = file.path('data', 'confirmatory', 'realworld', 'processed',
                     paste0(s$dataset_id, '.csv')),
    sha256 = sha256(processed_path),
    license = 'R-datasets-GPL-2-or-3',
    variable = s$variable,
    transform = 'raw',
    family_hint = s$family_hint,
    independence_group = s$independence_group,
    source_url = source_url,
    source_object = s$source_object,
    source_package = 'datasets',
    source_r_version = as.character(getRversion()),
    domain = s$domain,
    selection_rule = 'predeclared_one_parent_object_per_dataset_id',
    raw_path = file.path('data', 'confirmatory', 'realworld', 'raw',
                         paste0(s$dataset_id, '.csv')),
    raw_sha256 = sha256(raw_path),
    n_observations = length(x),
    stringsAsFactors = FALSE)
}

manifest <- do.call(rbind, rows)
if (nrow(manifest) != length(panel) || anyDuplicated(manifest$independence_group))
  stop('Invalid confirmatory R dataset manifest')
utils::write.csv(manifest, manifest_path, row.names = FALSE, quote = TRUE)
cat('Wrote', nrow(manifest), 'independent parent datasets to', manifest_path, '\n')
cat('Processed bytes:', sum(file.info(file.path(repo_root, manifest$path))$size), '\n')
