#!/usr/bin/env python3
"""Builds the card index used by the inkwellkeeper.app web deck viewer.

Reads the app's bundled set data (Inkwell Keeper/Data/*.json) and emits a compact
id -> card-facts JSON the static site decodes IWK2 share codes against.

Usage:
    python3 Scripts/generate_web_card_index.py [output_path]

Default output: ../inkwellkeeper-site/assets/card-index.json (sibling checkout).
Rerun and redeploy the site whenever a new set is added to the app.
"""

import json
import sys
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "Inkwell Keeper" / "Data"
DEFAULT_OUTPUT = (
    Path(__file__).resolve().parent.parent.parent
    / "inkwellkeeper-site" / "assets" / "card-index.json"
)
NON_SET_FILES = {"official_card_ids.json", "migration_map.json", "starter_decks.json"}


def load_cards():
    for path in sorted(DATA_DIR.glob("*.json")):
        if path.name in NON_SET_FILES:
            continue
        data = json.loads(path.read_text())
        cards = data.get("cards", data) if isinstance(data, dict) else data
        if not isinstance(cards, list):
            continue
        yield from cards


def main():
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUTPUT

    index = {}
    for card in load_cards():
        card_id = card.get("id")
        if not card_id:
            continue
        variant = card.get("variant", "Normal")
        # Foil/promo printings can share an id with the base card; prefer the normal one.
        if card_id in index and variant != "Normal":
            continue
        index[card_id] = {
            "n": card.get("name", ""),
            "c": card.get("cost", 0),
            "t": card.get("type", ""),
            "i": card.get("inkColor") or "",
            "w": 1 if card.get("inkwell") else 0,
            "s": card.get("setName", ""),
            "img": card.get("imageUrl", ""),
        }

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(index, separators=(",", ":"), ensure_ascii=False))
    print(f"Wrote {len(index)} cards to {output} ({output.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
