#!/usr/bin/env python3
"""Upload a verified T2 backup payload to a new Zenodo deposition.

The token is read only from ZENODO_TOKEN.  The script never stores or prints
the token.  Publication is explicit with --publish.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import requests


API = "https://zenodo.org/api"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--payload", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--title", default="Computational archive backup")
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args()

    token = os.environ.get("ZENODO_TOKEN", "")
    if not token:
        raise SystemExit("ZENODO_TOKEN is not available")
    if not args.payload.is_dir() or not args.manifest.is_file():
        raise SystemExit("Payload or manifest path is missing")

    headers = {"Authorization": f"Bearer {token}"}
    metadata = {
        "title": args.title,
        "upload_type": "other",
        "description": "Machine-generated computational archive backup.",
        "creators": [{"name": "ALRIER"}],
        "access_right": "open",
        "license": "CC-BY-4.0",
    }
    response = requests.post(f"{API}/deposit/depositions", params={"access_token": token},
                             json={"metadata": metadata}, timeout=120)
    response.raise_for_status()
    deposition = response.json()
    bucket = deposition["links"]["bucket"]

    files = [args.manifest, args.payload / "SHA256SUMS"] + sorted(args.payload.glob("*.tar"))
    for path in files:
        with path.open("rb") as stream:
            upload = requests.put(f"{bucket}/{path.name}", params={"access_token": token},
                                  data=stream, headers={"Content-Type": "application/octet-stream"},
                                  timeout=3600)
        upload.raise_for_status()
        print(f"UPLOADED {path.name} {path.stat().st_size}", flush=True)

    result = {"deposition": deposition, "files": [path.name for path in files]}
    if args.publish:
        published = requests.post(deposition["links"]["publish"], params={"access_token": token},
                                  timeout=120)
        published.raise_for_status()
        result["published"] = published.json()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    record = result.get("published", deposition)
    print(json.dumps({
        "id": record.get("id"),
        "doi": record.get("doi"),
        "record_url": (record.get("links") or {}).get("record_html") or
                      (record.get("links") or {}).get("html"),
        "published": bool(args.publish),
    }))


if __name__ == "__main__":
    main()
