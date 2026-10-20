# External checkpoint backup interface

T2 computes exclusively on GitHub-hosted runners. Local storage is a backup endpoint, not a compute worker. The remote target is optional and **not configured** by this commit.

`scripts/checkpoint_transfer.sh push SHARD` copies all locally completed stage files and optimizer checkpoints into `$T2_BACKUP_ROOT/$GITHUB_SHA/SHARD/` over authenticated SSH/rsync. `pull SHARD` restores that tree to `$T2_OUTPUT_ROOT/SHARD/`. The script does not delete remote files. Transfer failures return nonzero.

Required variables: `T2_BACKUP_HOST` (Tailscale DNS or stable SSH host), `T2_BACKUP_USER`, `T2_BACKUP_ROOT` (absolute destination), `T2_OUTPUT_ROOT` (defaults to `artifacts/ci`), and GitHub's `GITHUB_SHA`. Credentials must be stored in GitHub Actions secrets; verify SSH host keys and use limited-permission keys. Never commit keys or expose an SSH service publicly without controls.

**Codex integration tasks:** configure the receiver and secrets; run a periodic 15-minute uploader *while* long stages execute; check successful remote transfers and authenticate downloads; restore from the newest verified consistent checkpoint before the stage; add graceful handoff before the six-hour job limit; test forced interruption and bitwise/seed-equivalent continuation. A GitHub Actions artifact upload at stage completion is a second backup layer, but it cannot replace in-flight transfers.

A 15-minute upload schedule alone does not guarantee loss below 15 minutes: a transfer may fail, be delayed, or capture files while they are changing. Before marking production ready, use atomic checkpoint snapshots, checksum validation, immutable generations or a manifest published last, and a retry policy. Restore only complete snapshots. Long-running stages other than discovery also require resumable computation.

Repository commits are not intended as a 30-GB object store. Keep results in Actions artifacts and the local backup, and commit only lightweight verified metadata/manifests when appropriate.
