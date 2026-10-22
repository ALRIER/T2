# 00 — Environment and integrity

Use R 4.3.3 and the versions in `config/runtime_requirements.csv`.

Run from the repository root:

```bash
Rscript scripts/check_environment.R
Rscript tests/test_artifact_contract.R
```

Do not start a production stage if either check fails.  The source tree is the
authoritative code; this procedural folder documents and launches it.
