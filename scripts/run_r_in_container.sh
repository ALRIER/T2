#!/usr/bin/env bash
# Shared pinned R execution for GitHub Actions and local Docker runners.
set -euo pipefail
IMAGE="${T2_R_IMAGE:-ghcr.io/alrier/t2-r:4.3.3-statmod-v1}"
if ! command -v docker >/dev/null 2>&1; then echo "Docker is required for T2 pinned R runtime" >&2; exit 127; fi
ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
if [[ ! -d "$ROOT" ]]; then echo "Missing workspace: $ROOT" >&2; exit 2; fi
args=(run --rm -v "$ROOT:/workspace" -w /workspace)
# Forward declared experiment settings and nonsensitive Actions context.
while IFS='=' read -r key _; do
  case "$key" in
    T2_*|RW2_*|HG_*|EXTERNAL_*|SHARD|MODE|FAMILY|ENGINE|SEED|R_LIBS_USER|CI|GITHUB_SHA|GITHUB_RUN_ID)
      args+=(-e "$key") ;;
  esac
done < <(env)
exec docker "${args[@]}" "$IMAGE" "$@"
