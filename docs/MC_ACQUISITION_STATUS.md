# Monte Carlo empirical-anchor acquisition status

The following inputs were acquired locally under data/mc_validation/:

| Anchor | Local status | Source treatment |
|---|---|---|
| DS1 Wine Alcohol | acquired and hashed | UCI raw file plus transformed CSV |
| DS2 Forest Fires | acquired and hashed | UCI raw file plus log(area + 1) CSV |
| DS3 GBSG2 Survival | acquired and hashed | Rdatasets CSV; uncensored positive survival times |
| DS4 Lexical Decision RT | acquired and hashed | rtdists package speed_acc data; cleaned RT CSV |
| DS5 DAX log returns | acquired and hashed | `datasets::EuStockMarkets`; R-packaged daily European index data, DAX log-return transformation |

The DAX series is retained as a financial stress anchor. Its observed excess
kurtosis is outside the normal synthetic envelope, so the manifest marks it
`stress_out_of_family`; the adapter records that mismatch rather than treating
it as normal-shape coverage. The same explicit diagnostic-only policy is used
for the platykurtic Wine alcohol anchor. The full MC gate still requires a
reviewed license and SHA-256 for every accepted anchor.

The rejected OSF fallback download for DS4 was an MP4 container rather than a
tabular reaction-time dataset. It is retained as
data/mc_validation/raw/DS4_RT_LexicalDecision.source.rejected_mp4 for audit
traceability and is never loaded by the adapter.
