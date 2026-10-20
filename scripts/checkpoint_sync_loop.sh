#!/usr/bin/env bash
# Periodically publishes complete checkpoint snapshots during a long Actions job.
set -euo pipefail
shard="${1:?Usage: checkpoint_sync_loop.sh SHARD}"
interval="${T2_CHECKPOINT_TRANSFER_SECONDS:-900}"
[[ "$interval" =~ ^[0-9]+$ && "$interval" -ge 30 ]] || {
  echo "T2_CHECKPOINT_TRANSFER_SECONDS must be an integer >= 30" >&2; exit 2;
}
transfer="${T2_TRANSFER_SCRIPT:-scripts/checkpoint_transfer.sh}"
[[ -x "$transfer" ]] || { echo "Transfer script is not executable: $transfer" >&2; exit 2; }

push_once() {
  if [[ -d "${T2_OUTPUT_ROOT:-artifacts/ci}/$shard" ]]; then
    if ! "$transfer" push "$shard"; then
      echo "CHECKPOINT TRANSFER RETRYABLE FAILURE $shard" >&2
    fi
  fi
}

trap push_once EXIT
while true; do
  sleep "$interval"
  push_once
done
