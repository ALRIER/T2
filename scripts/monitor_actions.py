#!/usr/bin/env python3
"""Small dependency-free Actions monitor; runs from GitHub Actions on a schedule."""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def api(path):
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    repo = os.environ.get("GITHUB_REPOSITORY")
    if not token or not repo:
        raise SystemExit("GITHUB_TOKEN and GITHUB_REPOSITORY are required")
    url = "https://api.github.com/repos/" + repo + path
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer " + token,
        "X-GitHub-Api-Version": "2022-11-28",
    })
    with urllib.request.urlopen(req, timeout=20) as response:
        return json.load(response)


workflow = urllib.parse.quote(os.environ.get("T2_WORKFLOW_FILE", "smoke.yml"), safe="")
try:
    runs = api(f"/actions/workflows/{workflow}/runs?per_page=20")["workflow_runs"]
except urllib.error.HTTPError as exc:
    raise SystemExit(f"Actions API error: HTTP {exc.code}")

if not runs:
    print("ACTIONS MONITOR: no Verification run found")
    raise SystemExit(0)

run = runs[0]
run_id = run["id"]
jobs = api(f"/actions/runs/{run_id}/jobs?per_page=100")["jobs"]
counts = {}
for job in jobs:
    counts[job["status"]] = counts.get(job["status"], 0) + 1
print(json.dumps({
    "run_id": run_id,
    "run_number": run.get("run_number"),
    "status": run.get("status"),
    "conclusion": run.get("conclusion"),
    "jobs": counts,
    "html_url": run.get("html_url"),
}, sort_keys=True))

if run.get("status") == "completed" and run.get("conclusion") not in {"success", "skipped"}:
    raise SystemExit(1)
