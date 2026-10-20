#!/usr/bin/env bash
# Transfer bridge for external checkpoint storage. Never deletes published remote data.
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
command -v rsync >/dev/null && command -v ssh >/dev/null && command -v sha256sum >/dev/null || {
  echo "Requires rsync, ssh and sha256sum" >&2; exit 2;
}
root="${T2_OUTPUT_ROOT:-artifacts/ci}"
commit="${GITHUB_SHA:-local}"
[[ "$commit" =~ ^[A-Za-z0-9_-]{1,64}$ ]] || exit 2
local_dir="$root/$shard"
remote="${T2_BACKUP_USER}@${T2_BACKUP_HOST}"
remote_dir="${T2_BACKUP_ROOT%/}/$commit/$shard"
export RSYNC_RSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=15"
if [[ "$mode" == push ]]; then
  [[ -d "$local_dir" ]] || { echo "Local shard not found" >&2; exit 2; }
  snapshot="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  staging="$remote_dir/.staging/$snapshot"
  published="$remote_dir/snapshots/$snapshot"
  manifest="$(mktemp)"
  trap 'rm -f "$manifest"' EXIT
  (
    cd "$local_dir"
    find . -type f ! -name '*.tmp' ! -name '.t2_manifest.sha256' -print0 |
      sort -z | xargs -0 sha256sum
  ) > "$manifest"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=yes "$remote" "mkdir -p '$staging'"
  # A fresh staging directory is never used for restore. It becomes visible only
  # after both rsync operations complete and the READY marker is written.
  rsync -a --partial --delay-updates --exclude='*.tmp' "$local_dir/" "$remote:$staging/"
  rsync -a "$manifest" "$remote:$staging/.t2_manifest.sha256"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=yes "$remote" \
    "mv '$staging' '$published' && printf '%s\\n' '$snapshot' > '$published/.READY' && ln -sfn '$published' '$remote_dir/latest'"
else
  restore_dir="$root/.t2_restore_${shard}_$$"
  cleanup() { rm -rf -- "$restore_dir"; }
  trap cleanup EXIT
  mkdir -p "$restore_dir"
  if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=yes "$remote" \
      "test -f '$remote_dir/latest/.READY'"; then
    echo "No complete remote snapshot is available for $shard" >&2
    exit 3
  fi
  rsync -a --partial --delay-updates "$remote:$remote_dir/latest/" "$restore_dir/"
  [[ -f "$restore_dir/.t2_manifest.sha256" ]] || { echo "Remote manifest missing" >&2; exit 3; }
  (cd "$restore_dir" && sha256sum -c .t2_manifest.sha256)
  mkdir -p "$local_dir"
  rsync -a --exclude='.READY' --exclude='.t2_manifest.sha256' "$restore_dir/" "$local_dir/"
fi
echo "TRANSFER PASS $mode $shard"
