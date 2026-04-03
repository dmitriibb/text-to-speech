#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tarfile
import urllib.parse
import urllib.request


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CATALOG = REPO_ROOT / "packages" / "model_catalog" / "approved_models.json"
DEFAULT_ARCHIVE_CACHE = REPO_ROOT / ".cache" / "model-archives"
DEFAULT_MODELS_ROOT = REPO_ROOT / "models"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download and extract an approved Phase 0 TTS model."
    )
    parser.add_argument("--model-id", required=True, help="Model id from the catalog")
    parser.add_argument(
        "--catalog",
        default=str(DEFAULT_CATALOG),
        help="Path to the approved model catalog JSON",
    )
    parser.add_argument(
        "--archive-cache",
        default=str(DEFAULT_ARCHIVE_CACHE),
        help="Directory used for cached model archives",
    )
    parser.add_argument(
        "--models-root",
        default=str(DEFAULT_MODELS_ROOT),
        help="Directory where extracted models are stored",
    )
    parser.add_argument(
        "--force-download",
        action="store_true",
        help="Download the archive again even if it exists in cache",
    )
    parser.add_argument(
        "--force-extract",
        action="store_true",
        help="Extract the archive again even if the model is already present",
    )
    return parser.parse_args()


def load_catalog(catalog_path: Path) -> dict:
    with catalog_path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def find_model(catalog: dict, model_id: str) -> dict:
    for model in catalog["models"]:
        if model["id"] == model_id:
            return model
    raise SystemExit(f"Unknown model id: {model_id}")


def sha256_of_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_known_sha(path: Path, expected_sha: str) -> None:
    actual_sha = sha256_of_file(path)
    if actual_sha != expected_sha:
        raise SystemExit(
            f"SHA-256 mismatch for {path.name}: expected {expected_sha}, got {actual_sha}"
        )


def safe_extract_tar(archive_path: Path, destination: Path) -> None:
    with tarfile.open(archive_path, "r:*") as archive:
        members = archive.getmembers()
        for member in members:
            member_path = destination / member.name
            if not member_path.resolve().is_relative_to(destination.resolve()):
                raise SystemExit(f"Unsafe archive entry detected: {member.name}")
        archive.extractall(destination)


def download_file(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "phase0-model-fetch/1.0"})
    with urllib.request.urlopen(request) as response, destination.open("wb") as handle:
        shutil.copyfileobj(response, handle)


def write_local_metadata(model: dict, archive_path: Path, install_dir: Path) -> None:
    metadata = {
        "model_id": model["id"],
        "archive_name": archive_path.name,
        "archive_sha256_local": sha256_of_file(archive_path),
        "archive_sha256_upstream": model["source"]["archive_sha256"],
        "install_dir": str(install_dir),
        "archive_url": model["source"]["archive_url"],
    }
    marker_path = install_dir / ".phase0-fetch.json"
    with marker_path.open("w", encoding="utf-8") as handle:
        json.dump(metadata, handle, indent=2)
        handle.write("\n")


def main() -> None:
    args = parse_args()
    catalog_path = Path(args.catalog).resolve()
    archive_cache = Path(args.archive_cache).resolve()
    models_root = Path(args.models_root).resolve()

    catalog = load_catalog(catalog_path)
    model = find_model(catalog, args.model_id)
    if not model["status"]["approved_for_local_validation"]:
        raise SystemExit(f"Model {args.model_id} is not approved for local validation")

    archive_cache.mkdir(parents=True, exist_ok=True)
    models_root.mkdir(parents=True, exist_ok=True)

    archive_url = model["source"]["archive_url"]
    archive_name = Path(urllib.parse.urlparse(archive_url).path).name
    archive_path = archive_cache / archive_name
    install_dir = models_root / model["install"]["install_dir_name"]

    if args.force_download or not archive_path.exists():
        print(f"Downloading {archive_url}")
        download_file(archive_url, archive_path)
    else:
        print(f"Using cached archive {archive_path}")

    expected_sha = model["source"]["archive_sha256"]
    if expected_sha != "Unknown":
        verify_known_sha(archive_path, expected_sha)
        print(f"Verified upstream SHA-256 for {archive_path.name}")
    else:
        print(
            "Upstream SHA-256 is Unknown. "
            f"Local SHA-256 is {sha256_of_file(archive_path)}"
        )

    if install_dir.exists() and not args.force_extract:
        marker_path = install_dir / ".phase0-fetch.json"
        if marker_path.exists():
            print(f"Model already extracted at {install_dir}")
            return

    if install_dir.exists() and args.force_extract:
        shutil.rmtree(install_dir)

    print(f"Extracting {archive_path.name} into {models_root}")
    safe_extract_tar(archive_path, models_root)

    if not install_dir.exists():
        raise SystemExit(
            f"Expected extracted model directory {install_dir} was not created"
        )

    write_local_metadata(model, archive_path, install_dir)
    print(f"Model ready at {install_dir}")


if __name__ == "__main__":
    main()

