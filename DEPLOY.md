Deployment from a local computer with git and GitHub authentication:

```bash
git clone "${GITHUB_REPOSITORY_URL:-https://github.com/<owner>/<repository>.git}"
cd T2
# Copy all files from this package into the clone, keeping subdirectories intact.
git add -A
git commit -m "Add execution modules"
git push origin main
```

Do not delete prior repositories until all files appear in T2 and Actions tests pass.
