# Monte Carlo empirical-anchor acquisition status

The following inputs were acquired locally under data/mc_validation/:

| Anchor | Local status | Source treatment |
|---|---|---|
| DS1 Wine Alcohol | acquired and hashed | UCI raw file plus transformed CSV |
| DS2 Forest Fires | acquired and hashed | UCI raw file plus log(area + 1) CSV |
| DS3 GBSG2 Survival | acquired and hashed | Rdatasets CSV; uncensored positive survival times |
| DS4 Lexical Decision RT | acquired and hashed | rtdists package speed_acc data; cleaned RT CSV |
| DS5 SPY log returns | deliberately not retained | Yahoo states that information provided by Yahoo Finance must not be redistributed |

DS5 therefore remains an external, non-redistributable input. A private runner
may provide it through an out-of-repository path, but T2 will not accept it as a
checked-in full-run input. The full MC gate also requires a reviewed license
field and SHA-256 for every accepted anchor.

The rejected OSF fallback download for DS4 was an MP4 container rather than a
tabular reaction-time dataset. It is retained as
data/mc_validation/raw/DS4_RT_LexicalDecision.source.rejected_mp4 for audit
traceability and is never loaded by the adapter.
