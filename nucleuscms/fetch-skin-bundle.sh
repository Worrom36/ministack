#!/bin/bash
#===============================================================================
#  MINISTACK: fetch Nucleus skins from Wayback Machine and build skins-bundle.zip
#  Source: skins.nucleuscms.org (2016 archive snapshot)
#===============================================================================

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ARCHIVE_SNAPSHOT="${ARCHIVE_SNAPSHOT:-20160112042906}"
BROWSER_URL="https://web.archive.org/web/20160131063758/http://skins.nucleuscms.org/browser/index.php?type=1"
# id_ returns raw archived bytes (without it Wayback serves HTML wrapper pages)
FILES_BASE="https://web.archive.org/web/${ARCHIVE_SNAPSHOT}id_/http://skins.nucleuscms.org/files"
STAGING="$SCRIPT_DIR/data/fetch-staging"
INCLUDED_DIR="$SCRIPT_DIR/included"
DELAY_SEC="${DELAY_SEC:-4}"
MAX_RETRIES="${MAX_RETRIES:-3}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
log_step()  { printf "${CYAN}[STEP]${NC} %s\n" "$1"; }

if ! command -v python3 &>/dev/null; then
    log_error "python3 is required"
    exit 1
fi
if ! command -v curl &>/dev/null; then
    log_error "curl is required"
    exit 1
fi
if ! command -v zip &>/dev/null; then
    log_error "zip is required"
    exit 1
fi

export SCRIPT_DIR ARCHIVE_SNAPSHOT BROWSER_URL FILES_BASE STAGING DELAY_SEC MAX_RETRIES INCLUDED_DIR

python3 << 'PY'
import gzip
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
import zipfile
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path

script_dir = Path(os.environ["SCRIPT_DIR"])
included_dir = Path(os.environ["INCLUDED_DIR"])
staging = Path(os.environ["STAGING"])
browser_url = os.environ["BROWSER_URL"]
files_base = os.environ["FILES_BASE"]
archive_snapshot = os.environ["ARCHIVE_SNAPSHOT"]
delay_sec = float(os.environ["DELAY_SEC"])
max_retries = int(os.environ["MAX_RETRIES"])

bundle_zip = included_dir / "skins-bundle.zip"
manifest_path = included_dir / "skins-manifest.json"


def log(msg):
    print(msg, flush=True)


def is_html(data):
    return data.lstrip()[:1] == b"<"


def fetch_url(url, timeout=90):
    result = subprocess.run(
        [
            "curl", "-fsSL",
            "--max-time", str(int(timeout)),
            "-A", "MINISTACK-nucleuscms-fetch/1.0",
            url,
        ],
        capture_output=True,
    )
    if result.returncode != 0:
        err = result.stderr.decode("utf-8", "replace").strip()
        raise OSError(err or f"curl failed (exit {result.returncode})")
    return result.stdout


def fetch_url_with_retries(url, timeout=90):
    last_err = None
    for attempt in range(max_retries):
        if attempt:
            wait = delay_sec * (2 ** attempt)
            log(f"  retry in {wait:.0f}s...")
            time.sleep(wait)
        try:
            return fetch_url(url, timeout=timeout)
        except OSError as e:
            last_err = e
    raise last_err


def normalize_extracted_dir(extracted, skin_name):
    final = staging / skin_name
    if extracted != final:
        if final.exists():
            shutil.rmtree(final)
        extracted.rename(final)
    if not (final / "skinbackup.xml").exists() and not (final / "skindata.xml").exists():
        raise ValueError("skinbackup.xml not found after extract")
    return final


def is_dir_entry(name, names, info):
    if name.endswith("/"):
        return True
    if info.file_size != 0:
        return False
    prefix = name.rstrip("/") + "/"
    return any(n != name and n.startswith(prefix) for n in names)


def safe_extract_zip(zf, dest):
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    names = zf.namelist()
    for name in sorted(names, key=lambda n: (n.count("/"), n)):
        info = zf.getinfo(name)
        target = dest / name
        if is_dir_entry(name, names, info):
            if target.exists() and target.is_file():
                target.unlink()
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.is_dir():
            shutil.rmtree(target)
        with zf.open(name) as src, open(target, "wb") as dst:
            shutil.copyfileobj(src, dst)


def extract_skin_zip(data, skin_name):
    final = staging / skin_name
    if final.exists():
        shutil.rmtree(final)

    tmp = staging / f".extract-{skin_name}"
    if tmp.exists():
        shutil.rmtree(tmp)

    with zipfile.ZipFile(BytesIO(data)) as zf:
        names = zf.namelist()
        xml_files = [n for n in names if n.endswith("skinbackup.xml") or n.endswith("skindata.xml")]
        if not xml_files:
            raise ValueError("no skinbackup.xml or skindata.xml in zip")
        root = xml_files[0].split("/")[0].rstrip("/") or skin_name
        safe_extract_zip(zf, tmp)
        extracted = tmp / root
        if not extracted.exists():
            raise ValueError(f"expected root folder {root!r} not found in zip")
        extracted.rename(final)

    if tmp.exists():
        shutil.rmtree(tmp, ignore_errors=True)

    if not (final / "skinbackup.xml").exists() and not (final / "skindata.xml").exists():
        raise ValueError("skinbackup.xml not found after extract")


def extract_skin_tar(data, skin_name):
    final = staging / skin_name
    if final.exists():
        shutil.rmtree(final)

    with tarfile.open(fileobj=BytesIO(data)) as tf:
        members = tf.getmembers()
        xml_members = [m for m in members if m.name.endswith("skinbackup.xml") or m.name.endswith("skindata.xml")]
        if not xml_members:
            raise ValueError("no skinbackup.xml or skindata.xml in tar archive")
        root = xml_members[0].name.split("/")[0].rstrip("/") or skin_name
        tf.extractall(staging)
        normalize_extracted_dir(staging / root, skin_name)


def extract_skin_archive(data, skin_name):
    if data[:2] == b"PK":
        extract_skin_zip(data, skin_name)
        return
    if data[:2] == b"\x1f\x8b":
        extract_skin_tar(gzip.decompress(data), skin_name)
        return
    if data.startswith(b"<?xml") or b"<nucleus" in data[:800].lower():
        final = staging / skin_name
        if final.exists():
            shutil.rmtree(final)
        final.mkdir(parents=True)
        (final / "skinbackup.xml").write_bytes(data)
        return
    raise ValueError(f"unknown archive format (magic {data[:4]!r})")


def download_and_extract(url, skin_name):
    last_err = None
    for attempt in range(max_retries):
        if attempt:
            wait = delay_sec * (2 ** attempt)
            log(f"  retry in {wait:.0f}s...")
            time.sleep(wait)
        try:
            data = fetch_url(url, timeout=90)
            if is_html(data):
                raise ValueError("HTML response from Wayback (rate limit or missing capture)")
            extract_skin_archive(data, skin_name)
            return
        except (OSError, zipfile.BadZipFile, ValueError) as e:
            last_err = e
    raise last_err


def parse_catalog():
    log("[STEP] Fetching skin catalog from Wayback...")
    html = fetch_url_with_retries(browser_url, timeout=90).decode("utf-8", "replace")
    m = re.search(r"var downloads = Array\(([^)]+)\)", html)
    if not m:
        sys.exit("Could not parse downloads[] from archived Skin Browser")
    zips = [x.strip().strip("'") for x in m.group(1).split(",")]
    log(f"[INFO] Catalog: {len(zips)} skin zips")
    return zips


def skin_name_from_zip(zip_name):
    if zip_name.endswith("_skin.zip"):
        return zip_name[: -len("_skin.zip")]
    return Path(zip_name).stem


def main():
    staging.mkdir(parents=True, exist_ok=True)
    zips = parse_catalog()
    ok = []
    skipped = []
    failed = []

    for i, zip_name in enumerate(zips, 1):
        skin = skin_name_from_zip(zip_name)
        dest = staging / skin
        if (dest / "skinbackup.xml").exists() or (dest / "skindata.xml").exists():
            log(f"[INFO] ({i}/{len(zips)}) skip existing: {skin}")
            skipped.append(skin)
            ok.append(skin)
            continue

        url = f"{files_base}/{zip_name}"
        log(f"[INFO] ({i}/{len(zips)}) downloading {zip_name}...")
        try:
            download_and_extract(url, skin)
            ok.append(skin)
            log(f"[INFO]   ok: {skin}")
        except Exception as e:
            failed.append({"zip": zip_name, "skin": skin, "error": str(e)})
            log(f"[WARN]   failed: {skin} — {e}")

        if i < len(zips):
            time.sleep(delay_sec)

    bundled = sorted(
        d.name
        for d in staging.iterdir()
        if d.is_dir()
        and ((d / "skinbackup.xml").exists() or (d / "skindata.xml").exists())
    )

    log("[STEP] Building skins-bundle.zip...")
    included_dir.mkdir(parents=True, exist_ok=True)
    tmp_zip = script_dir / "data" / "skins-bundle.zip"
    tmp_zip.parent.mkdir(parents=True, exist_ok=True)
    if tmp_zip.exists():
        tmp_zip.unlink()

    subprocess.run(
        ["zip", "-rq", str(tmp_zip), "."],
        cwd=staging,
        check=True,
    )
    shutil.move(str(tmp_zip), bundle_zip)

    total_bytes = bundle_zip.stat().st_size
    manifest = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "archive_snapshot": archive_snapshot,
        "source": "skins.nucleuscms.org via web.archive.org",
        "catalog_count": len(zips),
        "bundled_count": len(bundled),
        "skipped_resumed": len(skipped),
        "failed_count": len(failed),
        "total_bytes": total_bytes,
        "bundled_skins": bundled,
        "failed": failed,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    pct = (len(bundled) / len(zips) * 100) if zips else 0
    log(f"[INFO] Bundle: {bundle_zip} ({total_bytes / 1024 / 1024:.1f} MiB)")
    log(f"[INFO] Skins: {len(bundled)}/{len(zips)} ({pct:.0f}%), failed: {len(failed)}")
    log(f"[INFO] Manifest: {manifest_path}")

    if pct < 90 and failed:
        log(f"[WARN] Less than 90% bundled — re-run to resume failed downloads")
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
PY

exit_code=$?
if [ "$exit_code" -eq 0 ]; then
    log_info "Done: $INCLUDED_DIR/skins-bundle.zip"
else
    log_warn "Completed with failures — re-run to resume (existing skins in data/fetch-staging/ are kept)"
fi
exit "$exit_code"
