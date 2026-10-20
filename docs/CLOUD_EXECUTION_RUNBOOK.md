# T2 cloud execution runbook

## Operating model

GitHub Actions is the only compute layer. Every full shard runs on an isolated hosted runner, and the local machine is a durable backup receiver. The runner publishes complete snapshots every 15 minutes and once more when the job exits. A rerun can restore the newest verified local snapshot and then the previous Actions artifact.

The scheduled `Actions monitor` workflow runs every 15 minutes. It reports the newest Verification run and job counts through the Actions log. It does not use Codex, and it does not silently start a new scientific run.

## Local receiver

The receiver needs SSH and rsync reachable through the private Tailscale network. Create a dedicated non-login backup user with write permission only below one directory, for example `/srv/t2-backup`; do not expose SSH publicly. The SSH public key used by Actions must be restricted to that user and directory. Keep the host public key in the reviewed `T2_BACKUP_KNOWN_HOSTS` secret.

The receiver must have enough free space for at least two complete copies of the largest expected shard. Published snapshots are never deleted by T2, so retention and disk cleanup are an operator policy, not an automatic experiment action.

## GitHub configuration

Set these repository variables:

- `T2_BACKUP_HOST`: the Tailscale DNS name or address of the local receiver.
- `T2_BACKUP_USER`: the restricted receiver account.
- `T2_BACKUP_ROOT`: an absolute destination such as `/srv/t2-backup`.

Set these repository secrets:

- `T2_BACKUP_SSH_KEY`: private key for the restricted receiver account.
- `T2_BACKUP_KNOWN_HOSTS`: reviewed SSH host-key lines for the receiver.
- `TS_OAUTH_CLIENT_ID` and `TS_OAUTH_SECRET`: Tailscale OAuth credentials restricted to the `tag:ci` tag.

The `full` job fails in `backup-preflight` if any of these settings is absent. This is intentional: a cloud run without a verified recovery destination is not production-ready.

## Launch and recovery

1. Run `Verification` with `mode=smoke` and confirm preflight, smoke, artifact and checkpoint tests.
2. Confirm the local receiver has a snapshot with `.READY` and a valid `.t2_manifest.sha256` after a pilot shard.
3. Run `Verification` with `mode=full` and leave `resume_run_id` empty for the first run.
4. If a run expires or a shard fails, dispatch `mode=full` again with the failed run ID in `resume_run_id`. The workflow restores the local snapshot first and uses the prior Actions artifact as a second recovery source.
5. Do not resume across a code/configuration/runtime change. The checkpoint contract rejects a commit or configuration mismatch.

The six-hour Actions timeout remains a hard job limit. Checkpointing makes the work restartable; it does not extend a single job beyond that limit. A full run may therefore require multiple bounded runs, each reusing completed stage/checkpoint state.

## Credit and storage boundary

The Python synchronizer and monitor execute in GitHub Actions. They consume Actions minutes and artifact/storage quota, not Codex credits. Keep large raw files, CSVs and RDS chunks in the local backup and Actions artifacts; do not commit them to Git. The repository should contain code, manifests, small metadata and reproducibility documents only.
