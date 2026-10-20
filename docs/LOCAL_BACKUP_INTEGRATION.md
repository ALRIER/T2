# External checkpoint backup interface

T2 computes exclusively on GitHub-hosted runners. Local storage is a backup endpoint, not a compute worker. The full Actions matrix is intentionally blocked until this route passes its preflight.

`scripts/checkpoint_transfer.sh push SHARD` publishes a complete, immutable snapshot under `$T2_BACKUP_ROOT/$GITHUB_SHA/SHARD/snapshots/` over authenticated SSH/rsync. The `latest` symlink is advanced only after the copy and manifest upload finish. `pull SHARD` reads only a snapshot with `.READY`, verifies `.t2_manifest.sha256`, and then restores it to `$T2_OUTPUT_ROOT/SHARD/`. The script does not delete published remote data. Transfer failures return nonzero.

Required variables: `T2_BACKUP_HOST` (Tailscale DNS or stable SSH host), `T2_BACKUP_USER`, `T2_BACKUP_ROOT` (absolute destination), `T2_OUTPUT_ROOT` (defaults to `artifacts/ci`), and GitHub's `GITHUB_SHA`. Credentials must be stored in GitHub Actions secrets; verify SSH host keys and use limited-permission keys. Never commit keys or expose an SSH service publicly without controls.

The full workflow uses `tailscale/github-action@v4`, a restricted `tag:ci` identity, verified SSH host keys, and `scripts/checkpoint_sync_loop.sh` to publish every 15 minutes plus a final snapshot. A rerun with `resume_run_id` first attempts the newest verified local snapshot and then falls back to the prior Actions artifact. A GitHub Actions artifact upload at stage completion is a second backup layer, but it cannot replace in-flight transfers.

A 15-minute upload schedule alone does not guarantee loss below 15 minutes: a transfer may fail or be delayed. The snapshot marker, checksum validation, immutable generations and retry-on-next-cycle policy prevent restoring partial transfers. Discovery is generation-resumable; other long-running stages remain stage-resumable through their atomic stage artifacts and status markers.

Required repository configuration before `mode=full`:

- Variables: `T2_BACKUP_HOST`, `T2_BACKUP_USER`, `T2_BACKUP_ROOT`.
- Secrets: `T2_BACKUP_SSH_KEY`, `T2_BACKUP_KNOWN_HOSTS`, `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_SECRET`.
- The local receiver must run SSH/rsync on the Tailscale network, accept the key with write access only to `T2_BACKUP_ROOT`, and have enough free disk space.
- Do not use `ssh-keyscan` in Actions; `T2_BACKUP_KNOWN_HOSTS` must be prepared and reviewed on the operator side.

The scheduled `Actions monitor` workflow consumes GitHub Actions minutes, not Codex credits. It reports the latest Verification run and job counts every 15 minutes; it does not make decisions about scientific validity or silently restart failed runs.

Repository commits are not intended as a 30-GB object store. Keep results in Actions artifacts and the local backup, and commit only lightweight verified metadata/manifests when appropriate.
