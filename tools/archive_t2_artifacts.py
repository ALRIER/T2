#!/usr/bin/env python3
"""Preserve every artifact from a GitHub Actions run on local disk.

Usage:
  GITHUB_TOKEN=... python3 tools/archive_t2_artifacts.py --run-id 39618194458 --output /path/to/T2-backup
Requires read-only access to Actions artifacts. Safe to rerun.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile
from urllib.request import Request, urlopen
from urllib.request import HTTPRedirectHandler, build_opener
from urllib.error import HTTPError
from urllib.parse import urlsplit
from zipfile import ZipFile

API = "https://api.github.com"

def request(url):
    token = os.environ["GITHUB_TOKEN"]
    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    return urlopen(Request(url, headers=headers), timeout=180)

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def download(url):
    """Open an artifact download without leaking the API token on redirect."""
    token = os.environ["GITHUB_TOKEN"]
    req = Request(url, headers={
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    try:
        return build_opener(NoRedirect()).open(req, timeout=180)
    except HTTPError as error:
        location = error.headers.get("Location")
        if error.code not in (301, 302, 303, 307, 308) or not location:
            raise
        host = (urlsplit(location).hostname or "").lower()
        if not (host.endswith(".blob.core.windows.net") or
                host.endswith(".actions.githubusercontent.com")):
            raise RuntimeError("Unexpected artifact redirect host: " + host)
        # The redirect URL is signed; do not send the GitHub token to it.
        return urlopen(location, timeout=180)

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default="ALRIER/T2")
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--require-complete-mc", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    artifacts = []
    page = 1
    while True:
        url = f"{API}/repos/{args.repo}/actions/runs/{args.run_id}/artifacts?per_page=100&page={page}"
        with request(url) as response:
            batch = json.load(response)["artifacts"]
        artifacts.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    mc = {a["name"] for a in artifacts if a["name"].startswith("mc-") and not a.get("expired")}
    if args.require_complete_mc and len(mc) != 54:
        raise SystemExit(f"Canonical Monte Carlo has {len(mc)} of 54 artifacts; no complete archive yet.")
    records = []
    for a in artifacts:
        name = a["name"]
        if a.get("expired"):
            raise RuntimeError("Expired artifact: " + name)
        # GitHub artifact names never contain separators, but enforce that assumption.
        if "/" in name or "\\" in name or name in (".", ".."):
            raise ValueError("Unsafe artifact name: " + name)
        dest = args.output / (name + ".zip")
        expected = a.get("digest") or ""
        if dest.exists():
            digest = sha256(dest)
            if expected and expected != "sha256:" + digest:
                raise RuntimeError("Existing local archive differs from GitHub: " + name)
        else:
            fd, tmp = tempfile.mkstemp(dir=args.output, suffix=".partial")
            os.close(fd)
            try:
                h = hashlib.sha256()
                with download(a["archive_download_url"]) as response, open(tmp, "wb") as stream:
                    for block in iter(lambda: response.read(1024 * 1024), b""):
                        stream.write(block)
                        h.update(block)
                digest = h.hexdigest()
                if expected and expected != "sha256:" + digest:
                    raise RuntimeError("Downloaded digest mismatch: " + name)
                with ZipFile(tmp) as z:
                    bad = z.testzip()
                    if bad is not None:
                        raise RuntimeError("ZIP integrity failure: " + name + "/" + bad)
                os.replace(tmp, dest)
            finally:
                if os.path.exists(tmp):
                    os.unlink(tmp)
        records.append({
            "name": name, "artifact_id": a["id"], "sha256": sha256(dest),
            "bytes": dest.stat().st_size, "created_at": a.get("created_at"),
            "expires_at": a.get("expires_at"), "github_digest": expected,
        })
        print("VERIFIED", name, flush=True)
    manifest = {
        "repository": args.repo, "workflow_run_id": args.run_id,
        "canonical_mc_count": len(mc), "total_artifacts": len(records),
        "artifacts": sorted(records, key=lambda x: x["name"]),
    }
    temp_manifest = args.output / ".manifest.json.partial"
    temp_manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    os.replace(temp_manifest, args.output / "manifest.json")
    print(f"ARCHIVE COMPLETE: {len(records)} verified ZIPs, {len(mc)}/54 MC blocks")

if __name__ == "__main__":
    main()
