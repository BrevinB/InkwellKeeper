#!/usr/bin/env python3
"""Deduplicate the bundled card-image library down to a single AVIF per card.

Background
----------
`Inkwell Keeper/Resources/CardImages/` is a synchronized folder reference, so every
loose file ships to every device with no App Store thinning. The folder historically
accumulated three buckets of waste:

  * Orphan files whose basename does not match any card `uniqueId(+variant)` and are
    therefore never looked up by `LorcanaCard.localImageUrl()`
    (e.g. set-number names `3-001-normal.avif`, legacy `INK-001.jpg`).
  * Redundant JPGs that duplicate an AVIF already present for the same card (AVIF is
    tried first by the runtime, so the JPG is dead weight).
  * A small number of cards that only shipped as JPG and need a matching AVIF fetched.

This script mirrors the exact lookup the app performs and reduces the folder to
AVIF-only, keeping every card available offline.

The lookup it mirrors lives in
`Inkwell Keeper/Extensions/LorcanaCardExtensions.swift` (`localImageUrl()`), which
builds the filename `"<uniqueId><variantSuffix>.<ext>"`.

Usage
-----
    python3 Scripts/dedupe_card_images.py            # check-only: report, change nothing
    python3 Scripts/dedupe_card_images.py --apply    # fetch missing AVIFs, then delete

Safety interlock: a JPG is only ever deleted when a matching AVIF exists, so no card
loses its sole offline image.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path

# Repo root = parent of this script's directory (Scripts/ sits at the repo root).
REPO_ROOT = Path(__file__).resolve().parent.parent
APP_DIR = REPO_ROOT / "Inkwell Keeper"
DATA_DIR = APP_DIR / "Data"
IMAGES_DIR = APP_DIR / "Resources" / "CardImages"

# Mirror of `setFolderMap` in LorcanaCardExtensions.swift. Includes both straight and
# curly apostrophes so set names match regardless of how the JSON was authored.
SET_FOLDER_MAP = {
    "The First Chapter": "the_first_chapter",
    "Rise of the Floodborn": "rise_of_the_floodborn",
    "Into the Inklands": "into_the_inklands",
    "Ursula's Return": "ursulas_return",
    "Ursula’s Return": "ursulas_return",
    "Shimmering Skies": "shimmering_skies",
    "Azurite Sea": "azurite_sea",
    "Archazia's Island": "archazias_island",
    "Archazia’s Island": "archazias_island",
    "Reign of Jafar": "reign_of_jafar",
    "Fabled": "fabled",
    "Whispers in the Well": "whispers_in_the_well",
    "Winterspell": "winterspell",
    "Promo Set 1": "promo_set_1",
    "Promo Set 2": "promo_set_2",
    "Promo Set 3": "promo_set_3",
    "Challenge Promo": "challenge_promo",
    "D23 Collection": "d23_collection",
    "EPCOT Festival of the Arts": "epcot_festival_of_the_arts",
    "Lorcana Challenge Year 3": "lorcana_challenge_year_3",
    "Wilds Unknown": "wilds_unknown",
    "Attack of the Vine!": "attack_of_the_vine",
}

# Mirror of the `variantSuffix` switch in LorcanaCardExtensions.swift. JSON stores
# capitalized variant strings; we key on the lowercased value.
VARIANT_SUFFIX = {
    "normal": "",
    "foil": "",
    "enchanted": "-enchanted",
    "promo": "-promo",
    "borderless": "-borderless",
    "epic": "-epic",
    "iconic": "-iconic",
}


def mb(num_bytes: int) -> str:
    return f"{num_bytes / 1_048_576:.0f} MB"


def reachable_basename(card: dict) -> str | None:
    """The exact basename the runtime would look up, or None if it can't (no uniqueId)."""
    unique_id = card.get("uniqueId")
    if not unique_id:
        return None
    suffix = VARIANT_SUFFIX.get(str(card.get("variant", "Normal")).lower(), "")
    return f"{unique_id}{suffix}"


def load_cards() -> list[tuple[dict, str]]:
    """Return (card, folder) for every card in a set we ship images for."""
    out: list[tuple[dict, str]] = []
    for json_path in sorted(DATA_DIR.glob("*.json")):
        try:
            data = json.loads(json_path.read_text())
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        if not isinstance(data, dict) or "cards" not in data:
            continue
        folder = SET_FOLDER_MAP.get(data.get("setName", ""))
        if not folder or not (IMAGES_DIR / folder).is_dir():
            continue
        for card in data["cards"]:
            out.append((card, folder))
    return out


def index_existing() -> tuple[dict[str, Path], dict[str, Path]]:
    """Map basename -> path for every avif and jpg currently on disk."""
    avif: dict[str, Path] = {}
    jpg: dict[str, Path] = {}
    for path in IMAGES_DIR.rglob("*"):
        if path.suffix == ".avif":
            avif[path.stem] = path
        elif path.suffix == ".jpg":
            jpg[path.stem] = path
    return avif, jpg


def download_avif(url: str, dest: Path) -> bool:
    """Fetch an AVIF to dest. Returns True on a plausibly-valid download."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "inkwell-dedupe/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = resp.read()
    except Exception as exc:  # noqa: BLE001 - report and skip, never crash the run
        print(f"    ! download failed: {exc}")
        return False
    # AVIF files are ISO-BMFF; the box at offset 4 is 'ftyp'. Guard against HTML errors.
    if len(payload) < 64 or payload[4:8] != b"ftyp":
        print(f"    ! not a valid AVIF (len={len(payload)}), skipping")
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(payload)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Perform downloads and deletions. Without it, only report (check-only).",
    )
    args = parser.parse_args()
    apply = args.apply

    if not IMAGES_DIR.is_dir():
        print(f"error: {IMAGES_DIR} not found", file=sys.stderr)
        return 1

    cards = load_cards()
    avif, jpg = index_existing()

    reachable: set[str] = set()
    missing_avif: list[tuple[dict, str, str]] = []  # (card, folder, basename)
    no_unique_id = 0

    for card, folder in cards:
        base = reachable_basename(card)
        if base is None:
            no_unique_id += 1
            continue
        reachable.add(base)
        if base not in avif:
            image_url = card.get("imageUrl", "")
            if ".avif" in image_url:
                missing_avif.append((card, folder, base))

    before_bytes = sum(p.stat().st_size for p in IMAGES_DIR.rglob("*") if p.is_file())

    print(f"Mode: {'APPLY' if apply else 'CHECK-ONLY'}")
    print(f"Cards with a uniqueId considered: {len(reachable)}")
    print(f"Cards without a uniqueId (remote-only, untouched): {no_unique_id}")
    print(f"Existing AVIF files: {len(avif)}   Existing JPG files: {len(jpg)}")
    print(f"CardImages size before: {mb(before_bytes)}")
    print()

    # --- Step 1: fetch missing AVIFs -------------------------------------------------
    print(f"Step 1 — fetch missing AVIFs: {len(missing_avif)} card(s)")
    fetched = 0
    for card, folder, base in missing_avif:
        url = card.get("imageUrl", "")
        dest = IMAGES_DIR / folder / f"{base}.avif"
        print(f"  {base}.avif  <-  {url[:70]}")
        if apply:
            if download_avif(url, dest):
                avif[base] = dest
                fetched += 1
    if apply:
        print(f"  downloaded: {fetched}/{len(missing_avif)}")
    print()

    # --- Step 2: delete orphan files (basename not reachable) ------------------------
    orphans = [
        p
        for p in IMAGES_DIR.rglob("*")
        if p.suffix in (".avif", ".jpg") and p.stem not in reachable
    ]
    orphan_bytes = sum(p.stat().st_size for p in orphans)
    print(f"Step 2 — delete orphans (unreachable basenames): "
          f"{len(orphans)} files, {mb(orphan_bytes)}")
    if apply:
        for p in orphans:
            p.unlink()

    # --- Step 3: delete redundant JPGs (matching AVIF exists) ------------------------
    # Re-index after potential downloads/deletions so the interlock sees current state.
    avif_now = {p.stem for p in IMAGES_DIR.rglob("*.avif")} if apply else set(avif)
    redundant_jpg, blocked_jpg = [], []
    for p in IMAGES_DIR.rglob("*.jpg"):
        if p.stem in reachable and p.stem in avif_now:
            redundant_jpg.append(p)
        elif p.stem in reachable:
            blocked_jpg.append(p)  # reachable JPG with no AVIF -> never delete
    redundant_bytes = sum(p.stat().st_size for p in redundant_jpg)
    print(f"Step 3 — delete redundant JPGs (AVIF exists): "
          f"{len(redundant_jpg)} files, {mb(redundant_bytes)}")
    if blocked_jpg:
        print(f"  INTERLOCK: {len(blocked_jpg)} reachable JPG(s) kept (no AVIF yet): "
              f"{[p.stem for p in blocked_jpg][:10]}")
    if apply:
        for p in redundant_jpg:
            p.unlink()
    print()

    if apply:
        after_bytes = sum(p.stat().st_size for p in IMAGES_DIR.rglob("*") if p.is_file())
        remaining_jpg = list(IMAGES_DIR.rglob("*.jpg"))
        print(f"CardImages size after: {mb(after_bytes)}  "
              f"(saved {mb(before_bytes - after_bytes)})")
        print(f"Remaining JPG files: {len(remaining_jpg)} "
              f"{'(all are interlock-protected, no AVIF)' if remaining_jpg else ''}")
    else:
        projected = before_bytes - orphan_bytes - redundant_bytes
        print(f"Projected size after apply: ~{mb(projected)} "
              f"(run again with --apply to perform)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
