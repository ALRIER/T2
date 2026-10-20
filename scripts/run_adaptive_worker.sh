#!/usr/bin/env bash
set -euo pipefail

worker_id="${1:?Usage: run_adaptive_worker.sh WORKER_ID [MODE] [PLAN]}"
mode="${2:-full}"
plan="${3:-config/shard_plan.csv}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

profile_line="$(awk -F, -v id="$worker_id" 'NR>1 && $1==id {print; exit}' config/worker_profiles.csv)"
if [[ -z "$profile_line" ]]; then
  echo "Unknown worker profile: $worker_id" >&2
  exit 2
fi
IFS=',' read -r _worker _kind _max_parallel _reserve_cores _min_available_gb _temp_warn _temp_stop _temp_resume _requires_sensor <<< "$profile_line"
max_parallel="${T2_MAX_PARALLEL:-$_max_parallel}"
reserve_cores="${T2_RESERVE_CORES:-$_reserve_cores}"
min_available_gb="${T2_MIN_AVAILABLE_GB:-$_min_available_gb}"
temp_warn="${T2_TEMP_WARN_C:-$_temp_warn}"
temp_stop="${T2_TEMP_STOP_C:-$_temp_stop}"
requires_sensor="${T2_REQUIRES_TEMP_SENSOR:-$_requires_sensor}"
[[ -r "$plan" ]] || { echo "Missing shard plan: $plan" >&2; exit 2; }
[[ "$mode" == smoke || "$mode" == full ]] || { echo "Mode must be smoke or full" >&2; exit 2; }

temperature_c() {
  local value=""
  if command -v sensors >/dev/null 2>&1; then
    value="$(sensors 2>/dev/null | awk '
      /^[[:space:]]*(Package id|Core [0-9]+|temp[0-9]+):/ {
        if (match($0, /\+[0-9]+(\.[0-9]+)?/)) print substr($0, RSTART + 1, RLENGTH - 1)
      }
    ' | sort -nr | head -1 || true)"
  fi
  if [[ -z "$value" ]]; then
    value="$(for f in /sys/class/thermal/thermal_zone*/temp; do
      [[ -r "$f" ]] && awk '{printf "%.1f\n", $1/1000}' "$f"
    done | sort -nr | head -1 || true)"
  fi
  [[ -n "$value" ]] && printf '%s' "$value" || printf 'NA'
}
available_gb() { awk '/MemAvailable:/ {printf "%.2f", $2/1024/1024}' /proc/meminfo 2>/dev/null || printf 'NA'; }
cpu_cap() {
  local n; n="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
  n=$((n - reserve_cores)); (( n < 1 )) && n=1; printf '%s' "$n"
}

if [[ "$requires_sensor" == "TRUE" && "$(temperature_c)" == "NA" && "${T2_ALLOW_NO_TEMP_SENSOR:-0}" != "1" ]]; then
  echo "Temperature sensor required for $worker_id; verify hardware or set T2_ALLOW_NO_TEMP_SENSOR=1" >&2
  exit 2
fi

queue="$(mktemp)"
runtime_dir="${T2_RUNTIME_ROOT:-runtime/adaptive}/${worker_id}"
mkdir -p "$runtime_dir"
trap 'jobs -pr | xargs -r kill 2>/dev/null || true; rm -f "$queue"' EXIT INT TERM
awk -F, -v id="$worker_id" 'NR>1 && $1==id {print $0}' "$plan" > "$queue"
total="$(wc -l < "$queue")"
[[ "$total" -gt 0 ]] || { echo "No shards assigned to $worker_id"; exit 0; }

active=0; stable_ticks=0; pids=()
while [[ -s "$queue" || "$active" -gt 0 ]]; do
  still_running=()
  for pid in "${pids[@]}"; do
    state="$(ps -p "$pid" -o stat= 2>/dev/null | tr -d ' ' || true)"
    if [[ -z "$state" || "$state" == Z* ]]; then
      wait "$pid" || { echo "A shard failed; inspect $runtime_dir" >&2; exit 1; }
    else
      still_running+=("$pid")
    fi
  done
  pids=("${still_running[@]}")
  active="${#pids[@]}"
  temp="$(temperature_c)"; avail="$(available_gb)"
  if [[ "$temp" != NA ]] && awk "BEGIN {exit !($temp >= $temp_stop)}"; then
    echo "CRITICAL temperature ${temp}C; stopping safely" | tee -a "$runtime_dir/controller.log"
    exit 75
  fi
  if [[ "$temp" != NA ]] && awk "BEGIN {exit !($temp >= $temp_warn)}"; then
    allowed="$active"; stable_ticks=0
  else
    stable_ticks=$((stable_ticks + 1)); allowed="$max_parallel"
    (( stable_ticks < 2 )) && allowed="$active"
  fi
  cap="$(cpu_cap)"; (( allowed > cap )) && allowed="$cap"
  if [[ "$avail" != NA ]] && awk "BEGIN {exit !($avail < $min_available_gb)}"; then allowed="$active"; fi
  while [[ "$active" -lt "$allowed" && -s "$queue" ]]; do
    IFS=',' read -r assigned shard family engine seed weight < "$queue"
    sed -i '1d' "$queue"
    log="$runtime_dir/${shard}.log"
    echo "$(date -u +%FT%TZ),START,$shard,temp=$temp,available_gb=$avail" >> "$runtime_dir/controller.log"
    T2_RESUME=1 T2_WORKER_ID="$worker_id" Rscript scripts/run_shard.R "$mode" "$family" "$seed" "$engine" "$shard" >"$log" 2>&1 &
    pids+=("$!")
    active=$((active + 1))
  done
  if (( active > 0 )); then
    sleep 5
  elif [[ -s "$queue" ]]; then
    sleep 15
  fi
done
echo "ADAPTIVE WORKER PASS $worker_id ($total shards)"
