#!/usr/bin/env bash
# Optional transfer bridge for external checkpoint storage. Never deletes remote data.
set -euo pipefail
mode="${1:?Usage: checkpoint_transfer.sh push|pull SHARD}"
shard="${2:?Missing shard}"
[[ "$mode" == push || "$mode" == pull ]] || { echo "Expected push or pull" >&2; exit 2; }
[[ "$shard" =~ ^[A-Za-z0-9_-]{1,64}$ ]] || { echo "Invalid shard" >&2; exit 2; }
: "${T2_BACKUP_HOST:?Set T2_BACKUP_HOST to the SSH/Tailscale hostname}"
: "${T2_BACKUP_USER:?Set T2_BACKUP_USER}"
: "${T2_BACKUP_ROOT:?Set T2_BACKUP_ROOT to an absolute destination path}"
[[ "$T2_BACKUP_ROOT" =~ ^/[A-Za-z0-9_./-]+$ && "$T2_BACKUP_ROOT" != *".."* ]] || { echo "Invalid backup root" >&2; exit 2; }
[[ "$T2_BACKUP_HOST" =~ ^[A-Za-z0-9.-]+$ && "$T2_BACKUP_USER" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "Invalid SSH target" >&2; exit 2; }
command -v rsync >/dev/null && command -v ssh >/dev/null || { echo "Requires rsync and ssh" >&2; exit 2; }
root="${T2_OUTPUT_ROOT:-artifacts/ci}"
commit="${GITHUB_SHA:-local}"
[[ "$commit" =~ ^[A-Za-z0-9_-]{1,64}$ ]] || exit 2
local_dir="$root/$shard"
remote="${T2_BACKUP_USER}@${T2_BACKUP_HOST}"
remote_dir="${T2_BACKUP_ROOT%/}/$commit/$shard"
export RSYNC_RSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=15"
if [[ "$mode" == push ]]; then
  [[ -d "$local_dir" ]] || { echo "Local shard not found" >&2; exit 2; }
  ssh -o BatchMode=yes -o StrictHostKeyChecking=yes "$remote" "mkdir -p '$remote_dir'"
  # Copy to a staging directory and publish only when rsync completes successfully.
  rsync -a --partial --delay-updates --exclude='*.tmp' "$local_dir/" "$remote:$remote_dir/"
else
  mkdir -p "$local_dir"
  rsync -a --partial --delay-updates "$remote:$remote_dir/" "$local_dir/"
fi
echo "TRANSFER PASS $mode $shard"
