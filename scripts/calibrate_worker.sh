#!/usr/bin/env bash
set -euo pipefail

worker_id="${1:?Usage: calibrate_worker.sh WORKER_ID [MODE] [PLAN]}"
mode="${2:-full}"
plan="${3:-config/shard_plan.csv}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
[[ -f "$plan" ]] || { echo "Missing shard plan: $plan" >&2; exit 2; }

calibration_dir="${T2_RUNTIME_ROOT:-runtime}/calibration/${worker_id}"
mkdir -p "$calibration_dir"
selected="${T2_CALIBRATION_SHARD:-}"
if [[ -z "$selected" ]]; then
  selected="$(awk -F, -v id="$worker_id" 'NR>1 && $1==id {print $2; exit}' "$plan")"
fi
[[ -n "$selected" ]] || { echo "No shard assigned to $worker_id" >&2; exit 2; }

row="$(awk -F, -v id="$selected" 'NR>1 && $2==id {print; exit}' "$plan")"
[[ -n "$row" ]] || { echo "Shard not found in plan: $selected" >&2; exit 2; }
IFS=',' read -r assigned shard family engine seed weight <<< "$row"
log="$calibration_dir/${shard}.log"
start_epoch="$(date +%s)"
start_utc="$(date -u +%FT%TZ)"
set +e
T2_MAX_PARALLEL=1 T2_RESUME=1 bash scripts/run_adaptive_worker.sh "$worker_id" "$mode" <(printf 'worker_id,shard,family,engine,seed,estimated_weight\n%s\n' "$row") >"$log" 2>&1
status=$?
set -e
end_epoch="$(date +%s)"
end_utc="$(date -u +%FT%TZ)"
elapsed="$((end_epoch - start_epoch))"
printf 'worker_id,shard,family,engine,seed,status,start_utc,end_utc,elapsed_seconds,log\n%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
  "$worker_id" "$shard" "$family" "$engine" "$seed" "$status" "$start_utc" "$end_utc" "$elapsed" "$log" \
  > "$calibration_dir/result.csv"
cat "$calibration_dir/result.csv"
exit "$status"
