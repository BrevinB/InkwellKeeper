#!/usr/bin/env python3
"""
Sync missing Lorcana cards from LorCast into the app's bundled data.

The everyday case (new cards in known sets — promos, late-added enchanteds)
is fully automatic. A brand-new set needs one human decision — its set code —
and this script then scaffolds every file that historically got missed:
sets.json, the set JSON, SetsDataManager's filename map, ImportService's
Dreamborn set map, PricingService's setCodeMap, the pricing backend cron's
_SET_CODES, the pbxproj resource registration, and official_card_ids.json.

Usage:
    python3 Scripts/sync_new_cards.py                  # sync all known sets + regen official ids
    python3 Scripts/sync_new_cards.py --dry-run        # report what would change, write nothing
    python3 Scripts/sync_new_cards.py --ci             # like default, but never touches pbxproj/backend
    python3 Scripts/sync_new_cards.py --new-set 14 --code XXX --name "Set Name"
                                                       # scaffold a brand-new main set end to end
"""

import argparse
import json
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPTS_DIR.parent
DATA_DIR = REPO_ROOT / "Inkwell Keeper" / "Data"
APP_DIR = REPO_ROOT / "Inkwell Keeper"
DEFAULT_BACKEND_REPO = Path.home() / "Developer" / "lorcana-pricing-api"
LORCANAJSON_ALLCARDS = "https://lorcanajson.org/files/current/en/allCards.json"

sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(SCRIPTS_DIR))

import update_card_data as ucd  # noqa: E402  (conversion/merge helpers)
from check_for_updates import SET_MAPPING  # noqa: E402  (local id -> lorcast code)


def fetch_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "InkwellKeeper/1.0"})
    with urllib.request.urlopen(req, timeout=120) as response:
        return json.loads(response.read())


def load_sets_json() -> dict:
    with open(DATA_DIR / "sets.json", encoding="utf-8") as f:
        return json.load(f)


def build_targets(sets_doc: dict) -> list:
    """One sync target per entry in sets.json.

    The set code comes from the set's own data file, NOT sets.json — new cards'
    uniqueIds must match the prefix already stored in user collections, and
    sets.json codes have drifted (ARC vs ARI, URS vs TUR in the data).
    """
    targets = []
    for entry in sets_doc.get("sets", []):
        set_id = entry["id"]
        query = SET_MAPPING.get(set_id) or entry.get("setNumber") or ""
        if not query:
            print(f"  ! no LorCast query known for '{set_id}' — skipping")
            continue

        set_code = entry.get("setCode") or ""
        data_path = DATA_DIR / f"{set_id}.json"
        if data_path.exists():
            with open(data_path, encoding="utf-8") as f:
                doc = json.load(f)
            # New uniqueIds must match what existing cards use (those prefixes
            # live in user collections via CloudKit), so the dominant prefix of
            # the cards themselves outranks both setCode fields.
            prefixes = {}
            for c in doc.get("cards", []):
                uid = c.get("uniqueId") or ""
                if "-" in uid:
                    p = uid.rsplit("-", 1)[0]
                    prefixes[p] = prefixes.get(p, 0) + 1
            dominant = max(prefixes, key=prefixes.get) if prefixes else ""
            file_code = doc.get("setCode") or ""
            chosen = dominant or file_code or set_code
            if chosen != set_code and set_code:
                print(f"  ! '{set_id}': sets.json says {set_code}, data uses {chosen} — using {chosen}")
            set_code = chosen

        targets.append({
            "query": query.lower(),
            "filename": f"{set_id}.json",
            "set_code": set_code,
            "set_name": entry["name"],
        })
    return targets


def sync_target(target: dict, dry_run: bool) -> int:
    """Merge missing LorCast prints into one local set file. Returns cards added."""
    path = DATA_DIR / target["filename"]
    remote = ucd.fetch_set_prints(target["query"])
    if not remote:
        print(f"  {target['set_name']}: no results from LorCast (query '{target['query']}')")
        return 0

    converted = [ucd.to_app_card(c, target["set_code"], target["set_name"]) for c in remote]

    if not path.exists():
        print(f"  {target['set_name']}: local file missing — creating with {len(converted)} cards")
        if not dry_run:
            doc = {
                "setName": target["set_name"],
                "setCode": target["set_code"],
                "cardCount": len(converted),
                "cards": ucd.sort_cards(converted),
            }
            path.write_text(json.dumps(doc, indent=2, ensure_ascii=False), encoding="utf-8")
        return len(converted)

    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
    existing = doc.get("cards", [])
    existing_sigs = set()
    for c in existing:
        existing_sigs.update(ucd.card_signatures(c))
    new_cards = [c for c in converted if not (ucd.card_signatures(c) & existing_sigs)]

    if not new_cards:
        return 0

    print(f"  {target['set_name']}: +{len(new_cards)} new cards")
    for nc in new_cards:
        print(f"    + {nc['uniqueId'] or nc['id']} :: {nc['name']}")

    if not dry_run:
        merged = ucd.sort_cards(existing + new_cards)
        doc["cards"] = merged
        doc["cardCount"] = len(merged)
        path.write_text(json.dumps(doc, indent=2, ensure_ascii=False), encoding="utf-8")
    return len(new_cards)


def regen_official_ids(dry_run: bool) -> bool:
    """Rebuild official_card_ids.json (official app backup imports) from LorcanaJSON."""
    path = DATA_DIR / "official_card_ids.json"
    try:
        cards = fetch_json(LORCANAJSON_ALLCARDS)["cards"]
    except Exception as e:
        print(f"  ! couldn't fetch LorcanaJSON allCards: {e}")
        return False

    out = sorted(
        ({"i": c["id"], "s": str(c["setCode"]), "n": c["number"], "m": c["fullName"]}
         for c in cards if c.get("id") is not None and c.get("number") is not None),
        key=lambda x: x["i"],
    )

    old_count = 0
    if path.exists():
        old_count = len(json.loads(path.read_text(encoding="utf-8")).get("cards", []))
    if len(out) < old_count:
        print(f"  ! LorcanaJSON returned fewer ids ({len(out)}) than local ({old_count}) — not overwriting")
        return False
    if len(out) == old_count:
        print(f"  official_card_ids.json: up to date ({old_count} ids)")
        return False

    print(f"  official_card_ids.json: {old_count} → {len(out)} ids")
    if not dry_run:
        path.write_text(
            json.dumps({"cards": out}, separators=(",", ":"), ensure_ascii=False),
            encoding="utf-8",
        )
    return True


IMAGES_DIR = APP_DIR / "Resources" / "CardImages"

# Filename suffix per variant — must mirror LorcanaCardExtensions.localImageUrl()
VARIANT_SUFFIX = {
    "Normal": "", "Foil": "", "Enchanted": "-enchanted", "Promo": "-promo",
    "Epic": "-epic", "Iconic": "-iconic", "Borderless": "-borderless",
}


def download_missing_images(dry_run: bool) -> int:
    """Bundle AVIF images for any card that has an imageUrl but no local file.

    CardImages is a filesystem-synchronized Xcode group, so files written here
    are picked up by the next build automatically. Cards without a uniqueId
    (letter-suffixed reprints like Dalmatian Puppy 4a-4e) can't be named and
    keep loading remotely.
    """
    downloaded = 0
    skipped_no_uid = 0

    for data_path in sorted(DATA_DIR.glob("*.json")):
        if data_path.stem in ("sets", "migration_map", "starter_decks", "official_card_ids", ".json"):
            continue
        with open(data_path, encoding="utf-8") as f:
            doc = json.load(f)

        folder = IMAGES_DIR / data_path.stem
        for card in doc.get("cards", []):
            uid = card.get("uniqueId")
            url = card.get("imageUrl") or ""
            if not url:
                continue
            if not uid:
                skipped_no_uid += 1
                continue
            suffix = VARIANT_SUFFIX.get(card.get("variant") or "Normal", "")
            dest = folder / f"{uid}{suffix}.avif"
            if dest.exists():
                continue

            if dry_run:
                print(f"  would download {dest.relative_to(IMAGES_DIR)}")
                downloaded += 1
                continue

            folder.mkdir(parents=True, exist_ok=True)
            try:
                req = urllib.request.Request(url + ".avif", headers={"User-Agent": "InkwellKeeper/1.0"})
                try:
                    with urllib.request.urlopen(req, timeout=30) as r:
                        data = r.read()
                except Exception:
                    req = urllib.request.Request(url, headers={"User-Agent": "InkwellKeeper/1.0"})
                    with urllib.request.urlopen(req, timeout=30) as r:
                        data = r.read()
                dest.write_bytes(data)
                downloaded += 1
                if downloaded % 25 == 0:
                    print(f"  ...{downloaded} downloaded")
            except Exception as e:
                print(f"  ! {dest.name}: download failed: {e}")

    if skipped_no_uid:
        print(f"  {skipped_no_uid} cards have no uniqueId — left loading remotely")
    print(f"  images downloaded: {downloaded}")
    return downloaded


def discover_unknown_sets(sets_doc: dict) -> list:
    """LorCast sets that have no entry in sets.json yet."""
    known_names = {e["name"].lower() for e in sets_doc.get("sets", [])}
    known_numbers = {str(e.get("setNumber", "")).lower() for e in sets_doc.get("sets", [])}
    unknown = []
    for s in fetch_json(f"{ucd.LORCAST_API}/sets").get("results", []):
        code = str(s.get("code", "")).lower()
        if s.get("name", "").lower() in known_names or code in known_numbers:
            continue
        if code in {v.lower() for v in SET_MAPPING.values()}:
            continue
        unknown.append(s)
    return unknown


# --- One-line patchers for the maps that historically got missed ---

def patch_file(path: Path, anchor: str, insertion: str, already: str, label: str, dry_run: bool) -> bool:
    """Insert `insertion` on a new line before `anchor` unless `already` present."""
    if not path.exists():
        print(f"  ! {label}: {path} not found — patch manually")
        return False
    text = path.read_text(encoding="utf-8")
    if already in text:
        print(f"  {label}: already contains entry")
        return False
    idx = text.find(anchor)
    if idx == -1:
        print(f"  ! {label}: anchor not found — patch manually: {insertion.strip()}")
        return False
    print(f"  {label}: adding {insertion.strip()}")
    if not dry_run:
        path.write_text(text[:idx] + insertion + text[idx:], encoding="utf-8")
    return True


def scaffold_new_set(number: str, code: str, name: str, backend_repo: Path, ci: bool, dry_run: bool):
    set_id = (
        name.lower().replace("'", "").replace("!", "").replace("-", " ")
        .replace(",", " ").split()
    )
    set_id = "_".join(set_id)
    padded = number.zfill(3)

    print(f"\n=== Scaffolding new set: {name} (#{number}, {code}, id {set_id}) ===")

    # 1. Set card data file
    added = sync_target(
        {"query": number, "filename": f"{set_id}.json", "set_code": code, "set_name": name},
        dry_run,
    )

    # 2. sets.json entry
    sets_path = DATA_DIR / "sets.json"
    sets_doc = load_sets_json()
    if any(e["id"] == set_id for e in sets_doc["sets"]):
        print("  sets.json: entry already exists")
    else:
        lorcast_set = next(
            (s for s in fetch_json(f"{ucd.LORCAST_API}/sets").get("results", [])
             if str(s.get("code")) == number),
            {},
        )
        entry = {
            "id": set_id,
            "name": name,
            "setCode": code,
            "setNumber": number,
            "releaseDate": lorcast_set.get("released_at", ""),
            "cardCount": added,
            "description": "",
            "isReleased": True,
        }
        print(f"  sets.json: adding entry for {name}")
        if not dry_run:
            sets_doc["sets"].append(entry)
            sets_path.write_text(json.dumps(sets_doc, indent=2, ensure_ascii=False), encoding="utf-8")

    # 3. SetsDataManager filename map
    patch_file(
        DATA_DIR / "SetsDataManager.swift",
        anchor='            "attack_of_the_vine": "attack_of_the_vine.json"',
        insertion=f'            "{set_id}": "{set_id}.json",\n',
        already=f'"{set_id}"',
        label="SetsDataManager.setFilenames",
        dry_run=dry_run,
    )

    # 4. ImportService Dreamborn set map
    patch_file(
        APP_DIR / "Services" / "ImportService.swift",
        anchor='        case "P1": return "Promo Set 1"',
        insertion=f'        case "{padded}", "{number}": return "{name}"\n',
        already=f'case "{padded}"',
        label="ImportService.mapDreambornSetNumber",
        dry_run=dry_run,
    )

    # 5. PricingService setCodeMap
    patch_file(
        APP_DIR / "Services" / "PricingService.swift",
        anchor='        "Attack of the Vine!": "AOV",',
        insertion=f'        "{name}": "{code}",\n',
        already=f'"{name}": "{code}"',
        label="PricingService.setCodeMap",
        dry_run=dry_run,
    )

    if not ci:
        # 6. Pricing backend cron _SET_CODES
        patch_file(
            backend_repo / "cron" / "update_prices.py",
            anchor='    "Attack of the Vine!": "AOV",',
            insertion=f'    "{name}": "{code}",\n',
            already=f'"{name}": "{code}"',
            label="pricing backend _SET_CODES",
            dry_run=dry_run,
        )

        # 7. pbxproj resource registration
        if dry_run:
            print(f"  pbxproj: would register {set_id}.json in Resources")
        else:
            ruby = f'''
require "xcodeproj"
project = Xcodeproj::Project.open("Inkwell Keeper.xcodeproj")
target = project.targets.find {{ |t| t.name == "Inkwell Keeper" }}
existing = project.files.find {{ |f| (f.path || "").end_with?("attack_of_the_vine.json") }}
group = existing.parent
unless group.files.any? {{ |f| (f.path || "").end_with?("{set_id}.json") }}
  ref = group.new_reference("{set_id}.json")
  target.add_resources([ref])
  project.save
  puts "  pbxproj: registered {set_id}.json"
end
'''
            result = subprocess.run(
                ["ruby", "-e", ruby], cwd=REPO_ROOT, capture_output=True, text=True
            )
            print(result.stdout.strip() or "  pbxproj: already registered")
            if result.returncode != 0:
                print(f"  ! pbxproj registration failed — run manually:\n{result.stderr.strip()}")

    print(f"""
=== Remaining manual steps for {name} ===
  1. Download card images, then rerun Scripts/dedupe_card_images.py
  2. Write a real description in sets.json (placeholder was inserted)
  3. If a Core rotation happened, update coreLegalSets in DeckRulesService
  4. Deploy the pricing backend and refresh prices:
       cd {backend_repo}
       DOCKER_HOST="unix://$HOME/.docker/run/docker.sock" sam deploy --no-confirm-changeset
       aws lambda invoke --function-name lorcana-pricing-CronFunction-zb8D9gACYgFB \\
         --region us-east-2 --payload '{{}}' /tmp/out.json
  5. Build + run tests, then commit
""")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="report changes without writing")
    parser.add_argument("--ci", action="store_true", help="skip pbxproj/backend-repo steps (CI-safe)")
    parser.add_argument("--new-set", metavar="NUMBER", help="scaffold a new main set by LorCast number")
    parser.add_argument("--code", help="app set code for --new-set (e.g. AOV) — choose deliberately, it's baked into uniqueIds")
    parser.add_argument("--name", help="exact set name for --new-set (match LorCast, incl. punctuation)")
    parser.add_argument("--backend-repo", type=Path, default=DEFAULT_BACKEND_REPO)
    parser.add_argument("--skip-images", action="store_true", help="don't download missing bundled card images")
    args = parser.parse_args()

    if args.new_set and not (args.code and args.name):
        parser.error("--new-set requires --code and --name")

    sets_doc = load_sets_json()

    print("=== Syncing known sets ===")
    total_added = 0
    for target in build_targets(sets_doc):
        try:
            total_added += sync_target(target, args.dry_run)
        except Exception as e:
            print(f"  ! {target['set_name']}: sync failed: {e}")
        time.sleep(0.4)
    if total_added == 0:
        print("  all known sets up to date")

    print("\n=== Official app backup id map ===")
    ids_changed = regen_official_ids(args.dry_run)

    images_added = 0
    if not args.skip_images:
        print("\n=== Bundled card images ===")
        images_added = download_missing_images(args.dry_run)

    if args.new_set:
        scaffold_new_set(args.new_set, args.code, args.name, args.backend_repo, args.ci, args.dry_run)
    else:
        unknown = discover_unknown_sets(sets_doc)
        if unknown:
            print("\n=== New sets on LorCast (not scaffolded — need a set code decision) ===")
            for s in unknown:
                print(f"  {s.get('code')}: {s.get('name')} — rerun with:")
                print(f"    python3 Scripts/sync_new_cards.py --new-set {s.get('code')} --code <CODE> --name \"{s.get('name')}\"")

    changed = total_added > 0 or ids_changed or images_added > 0
    print(f"\n{'DRY RUN — nothing written. ' if args.dry_run else ''}"
          f"{'Changes made.' if changed else 'Everything up to date.'}")
    sys.exit(0)


if __name__ == "__main__":
    main()
