#!/usr/bin/env python3
"""Update Lorcana card data from LorCast.

Patches existing set JSONs with newly-released prints and creates fresh JSONs
for any set that doesn't yet exist locally. Schema matches the format consumed
by SetsDataManager (top-level setName/setCode/cardCount/cards).
"""

import json
import os
import time
import urllib.request
from typing import Any

LORCAST_API = "https://api.lorcast.com/v0"
DATA_DIR = "Inkwell Keeper/Data"

# Each entry describes one set we want to sync.
#   query:    LorCast `q=set:<value>` lookup (uses unique=prints)
#   filename: local JSON in DATA_DIR
#   set_code: app-side set code (used for uniqueId prefix and setCode field)
#   set_name: human-readable name; must match what SwiftUI expects
TARGETS = [
    {
        "query": "p1",
        "filename": "promo_set_1.json",
        "set_code": "P1",
        "set_name": "Promo Set 1",
    },
    {
        "query": "3",
        "filename": "into_the_inklands.json",
        "set_code": "ITI",
        "set_name": "Into the Inklands",
    },
    {
        "query": "c2",
        "filename": "lorcana_challenge_year_3.json",
        "set_code": "C2",
        "set_name": "Lorcana Challenge Year 3",
    },
    {
        "query": "12",
        "filename": "wilds_unknown.json",
        "set_code": "WU",
        "set_name": "Wilds Unknown",
    },
]


def fetch_json(url: str) -> Any:
    req = urllib.request.Request(url, headers={"User-Agent": "InkwellKeeper/1.0"})
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())


def fetch_set_prints(query: str) -> list:
    url = f"{LORCAST_API}/cards/search?q=set:{query}&unique=prints"
    data = fetch_json(url)
    return data.get("results", [])


def detect_variant(card: dict, set_name: str) -> str:
    rarity = (card.get("rarity") or "").lower()
    if "enchanted" in rarity:
        return "Enchanted"
    if "epic" in rarity:
        return "Epic"
    if "iconic" in rarity:
        return "Iconic"
    if "promo" in set_name.lower() or "promo" in rarity:
        return "Promo"
    return "Normal"


def to_app_card(card: dict, set_code: str, set_name: str) -> dict:
    variant = detect_variant(card, set_name)

    collector_number_raw = card.get("collector_number") or ""
    try:
        card_number = int(collector_number_raw)
    except ValueError:
        card_number = None

    unique_id = f"{set_code}-{card_number:03d}" if card_number is not None else None

    name = card.get("name", "")
    version = card.get("version") or ""
    full_name = f"{name} - {version}" if version else name

    name_part = full_name.replace(" ", "_").replace("-", "_").replace("'", "")
    id_number = card_number if card_number is not None else collector_number_raw or "0"
    card_id = f"{set_name.replace(' ', '_')}_{id_number}_{name_part}"
    if variant != "Normal":
        card_id += f"_{variant}"

    text = card.get("text") or ""
    flavor = card.get("flavor_text")
    if flavor:
        text = f"{text}\n\n{flavor}" if text else flavor

    type_value = card.get("type", [])
    if isinstance(type_value, list):
        type_value = " - ".join(type_value)

    rarity = card.get("rarity") or "Common"
    if isinstance(rarity, str):
        rarity = rarity.replace("_", " ").title()

    image_url = ""
    digital = (card.get("image_uris") or {}).get("digital") or {}
    image_url = digital.get("large") or digital.get("normal") or digital.get("small") or ""

    return {
        "id": card_id,
        "name": full_name,
        "cost": card.get("cost"),
        "type": type_value,
        "rarity": rarity,
        "setName": set_name,
        "cardText": text,
        "imageUrl": image_url,
        "variant": variant,
        "cardNumber": card_number,
        "uniqueId": unique_id,
        "inkwell": card.get("inkwell", False),
        "strength": card.get("strength"),
        "willpower": card.get("willpower"),
        "lore": card.get("lore"),
        "franchise": "",
        "inkColor": card.get("ink") or "",
    }


def image_fingerprint(card: dict) -> str | None:
    """Extract LorCast `crd_<hash>` token from imageUrl — stable across schema changes."""
    url = card.get("imageUrl") or ""
    marker = "crd_"
    idx = url.find(marker)
    if idx == -1:
        return None
    end = url.find(".", idx)
    return url[idx:end] if end != -1 else url[idx:]


def sort_cards(cards: list) -> list:
    """Order cards by cardNumber asc, with non-numeric/null collector numbers at the end."""
    def key(c: dict) -> tuple:
        n = c.get("cardNumber")
        if isinstance(n, int):
            return (0, n, c.get("name") or "")
        return (1, c.get("name") or "", c.get("id") or "")
    return sorted(cards, key=key)


def card_signatures(card: dict) -> set[str]:
    """All identifiers under which this card may already exist locally."""
    sigs: set[str] = set()
    uid = card.get("uniqueId")
    if uid:
        sigs.add(f"uid:{uid}")
    if card.get("id"):
        sigs.add(f"id:{card['id']}")
    fp = image_fingerprint(card)
    if fp:
        sigs.add(f"img:{fp}")
    return sigs


def sync_set(target: dict) -> dict:
    path = os.path.join(DATA_DIR, target["filename"])
    print(f"\n=== {target['set_name']} ({target['set_code']}) ===")

    remote = fetch_set_prints(target["query"])
    print(f"  fetched {len(remote)} prints from LorCast")

    converted = [to_app_card(c, target["set_code"], target["set_name"]) for c in remote]

    if os.path.exists(path):
        with open(path) as f:
            existing_doc = json.load(f)
        existing_cards = existing_doc.get("cards", [])
        existing_sigs: set[str] = set()
        for c in existing_cards:
            existing_sigs.update(card_signatures(c))
        new_cards = [c for c in converted if not (card_signatures(c) & existing_sigs)]
        print(f"  local: {len(existing_cards)}; new to add: {len(new_cards)}")
        for nc in new_cards:
            print(f"    + {nc['uniqueId'] or nc['id']} :: {nc['name']}")
        merged = sort_cards(existing_cards + new_cards)
        existing_doc["cards"] = merged
        existing_doc["cardCount"] = len(merged)
        existing_doc["setName"] = target["set_name"]
        existing_doc["setCode"] = target["set_code"]
        with open(path, "w") as f:
            json.dump(existing_doc, f, indent=2, ensure_ascii=False)
        return {"action": "updated", "added": len(new_cards), "total": len(merged)}

    print(f"  local file missing — creating new")
    sorted_converted = sort_cards(converted)
    doc = {
        "setName": target["set_name"],
        "setCode": target["set_code"],
        "cardCount": len(sorted_converted),
        "cards": sorted_converted,
    }
    with open(path, "w") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
    return {"action": "created", "added": len(converted), "total": len(converted)}


def main() -> None:
    if not os.path.isdir(DATA_DIR):
        raise SystemExit(f"DATA_DIR not found: {DATA_DIR} (run from project root)")

    summary = []
    for target in TARGETS:
        result = sync_set(target)
        summary.append((target["set_name"], result))
        time.sleep(0.4)

    print("\n=== Summary ===")
    for name, result in summary:
        print(f"  {name}: {result['action']} (+{result['added']}, total {result['total']})")


if __name__ == "__main__":
    main()
