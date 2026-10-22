#!/usr/bin/env python3
"""Reconstruct and package the completed confirmatory Actions artifacts.

The producer workflows publish one ZIP per family/seed.  This utility verifies
each ZIP, restores the canonical directory layout, and creates family-scoped
tar files suitable for Zenodo and later Actions ingestion.  It intentionally
fails closed when an expected artifact is missing.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import tarfile
from pathlib import Path
from zipfile import ZipFile


FAMILIES = ("normal", "lognormal", "weibull", "invgauss", "exgaussian", "exwald")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def safe_extract(archive: Path, destination: Path) -> int:
    destination.mkdir(parents=True, exist_ok=True)
    with ZipFile(archive) as bundle:
        bad = bundle.testzip()
        if bad is not None:
            raise RuntimeError(f"ZIP integrity failure: {archive.name}/{bad}")
        root = destination.resolve()
        for member in bundle.infolist():
            target = (destination / member.filename).resolve()
            if target != root and root not in target.parents:
                raise RuntimeError(f"Unsafe ZIP member in {archive.name}: {member.filename}")
        bundle.extractall(destination)
        return len(bundle.infolist())


def parse_artifact(name: str) -> tuple[str, str | None, int | None]:
    patterns = (
        (r"^extended-mc-(?P<family>[^-]+)-seed-(?P<seed>\d+)$", "mc"),
        (r"^validation-(?P<family>[^-]+)-seed-(?P<seed>\d+)$", "validation"),
        (r"^confirmatory-v2-(?P<family>[^-]+)-seed(?P<seed>\d+)$", "score"),
        (r"^confirmatory-v2-inference-(?P<family>[^-]+)$", "inference"),
    )
    for pattern, kind in patterns:
        match = re.match(pattern, name)
        if match:
            family = match.groupdict().get("family")
            seed = match.groupdict().get("seed")
            return kind, family, int(seed) if seed is not None else None
    if name == "independent-validation-realworld-input":
        return "realworld", None, None
    return "other", None, None


def add_tar(source: Path, destination: Path, arc_prefix: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    tmp = destination.with_suffix(destination.suffix + ".partial")
    if tmp.exists():
        tmp.unlink()
    with tarfile.open(tmp, "w") as bundle:
        if source.is_dir():
            for child in sorted(source.rglob("*")):
                bundle.add(child, arcname=str(Path(arc_prefix) / child.relative_to(source)))
        else:
            bundle.add(source, arcname=str(Path(arc_prefix) / source.name))
    tmp.replace(destination)


def add_selected_tar(source: Path, destination: Path, arc_prefix: str,
                     selected: set[str]) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    tmp = destination.with_suffix(destination.suffix + ".partial")
    if tmp.exists():
        tmp.unlink()
    with tarfile.open(tmp, "w") as bundle:
        for child in sorted(source.iterdir() if source.exists() else []):
            if child.name not in selected:
                continue
            for item in sorted(child.rglob("*")):
                bundle.add(item, arcname=str(Path(arc_prefix) / child.name / item.relative_to(child)))
    tmp.replace(destination)


def write_checksums(root: Path, files: list[Path]) -> None:
    payload = root / "payload"
    lines = [f"{sha256(path)}  {path.relative_to(payload)}" for path in sorted(files)]
    (root / "SHA256SUMS").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mc-archive", type=Path, required=True)
    parser.add_argument("--validation-archive", type=Path, required=True)
    parser.add_argument("--confirmatory-archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--allow-incomplete", action="store_true")
    args = parser.parse_args()

    reconstructed = args.output / "reconstructed"
    payload = args.output / "payload"
    reconstructed.mkdir(parents=True, exist_ok=True)
    payload.mkdir(parents=True, exist_ok=True)

    records: list[dict[str, object]] = []
    expected: dict[str, set[str]] = {
        "mc": {f"{family}:{seed}" for family in FAMILIES for seed in range(9, 21)},
        "validation": {f"{family}:{seed}" for family in FAMILIES for seed in range(21, 27)},
        "score": {f"{family}:{seed}" for family in FAMILIES for seed in range(21, 27)},
        "inference": set(FAMILIES),
        "realworld": {"realworld"},
    }
    seen: dict[str, set[str]] = {key: set() for key in expected}

    archive_dirs = (args.mc_archive, args.validation_archive, args.confirmatory_archive)
    for archive_dir in archive_dirs:
        for archive in sorted(archive_dir.glob("*.zip")):
            kind, family, seed = parse_artifact(archive.stem)
            if kind == "other":
                continue
            if kind in ("mc", "validation"):
                assert family is not None and seed is not None
                destination = reconstructed / "mc_canonical" / "v2_shared_base_crn" / "full" / family / f"seed{seed:02d}"
                key = f"{family}:{seed}"
            elif kind == "score":
                assert family is not None and seed is not None
                destination = reconstructed / "confirmatory_v2" / "score" / family
                key = f"{family}:{seed}"
            elif kind == "inference":
                assert family is not None
                destination = reconstructed / "confirmatory_v2" / "inference" / family
                key = family
            else:
                destination = reconstructed / "artifacts" / "ci" / "shared"
                key = "realworld"

            members = safe_extract(archive, destination)
            seen[kind].add(key)
            records.append({
                "artifact": archive.stem,
                "kind": kind,
                "family": family,
                "seed": seed,
                "source_archive": archive.name,
                "source_sha256": sha256(archive),
                "members": members,
            })

    missing = {kind: sorted(expected[kind] - seen[kind]) for kind in expected if expected[kind] - seen[kind]}
    if missing and not args.allow_incomplete:
        raise SystemExit("Missing expected artifacts: " + json.dumps(missing, sort_keys=True))

    # Family archives preserve the exact paths consumed by the R loaders.
    for family in FAMILIES:
        mc_root = reconstructed / "mc_canonical" / "v2_shared_base_crn" / "full" / family
        add_selected_tar(
            mc_root,
            payload / f"t2_mc_canonical_{family}_seeds09_20.tar",
            "mc_canonical/v2_shared_base_crn/full/" + family,
            {f"seed{seed:02d}" for seed in range(9, 21)},
        )
        add_selected_tar(
            mc_root,
            payload / f"t2_validation_{family}_seeds21_26.tar",
            "mc_canonical/v2_shared_base_crn/full/" + family,
            {f"seed{seed:02d}" for seed in range(21, 27)},
        )
        score_root = reconstructed / "confirmatory_v2" / "score" / family
        add_tar(score_root, payload / f"t2_confirmatory_scores_{family}_seeds21_26.tar", "confirmatory_v2/score/" + family)
        inference_root = reconstructed / "confirmatory_v2" / "inference" / family
        add_tar(inference_root, payload / f"t2_confirmatory_inference_{family}.tar", "confirmatory_v2/inference/" + family)

    realworld_root = reconstructed / "artifacts" / "ci" / "shared"
    add_tar(realworld_root, payload / "t2_realworld_input.tar", "artifacts/ci/shared")

    manifest = {
        "format": "t2_confirmatory_backup_v1",
        "source_runs": {
            "extended_monte_carlo": 39695221993,
            "independent_validation": 39707832846,
            "confirmatory_v2": 39763527346,
        },
        "families": list(FAMILIES),
        "expected": {key: len(value) for key, value in expected.items()},
        "observed": {key: len(value) for key, value in seen.items()},
        "missing": missing,
        "artifacts": records,
    }
    (args.output / "backup_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    files = sorted(payload.glob("*.tar"))
    write_checksums(args.output, files)
    print(json.dumps({"output": str(args.output), "payload_files": len(files), "missing": missing}, indent=2))


if __name__ == "__main__":
    main()
