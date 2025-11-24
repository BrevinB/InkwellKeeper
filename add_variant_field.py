#!/usr/bin/env python3
"""
Add Variant field to all enchanted cards in JSON files
"""

import json
import os

DATA_DIR = "Inkwell Keeper/Data"

JSON_FILES = [
    "the_first_chapter.json",
    "rise_of_the_floodborn.json",
    "into_the_inklands.json",
    "ursulas_return.json",
    "shimmering_skies.json",
    "azurite_sea.json",
    "fabled.json",
    "archazias_island.json",
    "reign_of_jafar.json",
    "whispers_in_the_well.json",
]

def add_variant_field():
    """Add Variant field to enchanted cards"""
    print("✨ Adding Variant field to enchanted cards")
    print("=" * 60)

    total_updated = 0

    for json_file in JSON_FILES:
        file_path = os.path.join(DATA_DIR, json_file)

        if not os.path.exists(file_path):
            continue

        with open(file_path, 'r') as f:
            data = json.load(f)

        updated_count = 0

        for card in data.get("cards", []):
            # If card is enchanted and doesn't have Variant field, add it
            if card.get("Rarity") == "Enchanted" and "Variant" not in card:
                card["Variant"] = "Enchanted"
                updated_count += 1
                total_updated += 1
                print(f"  ✅ {card.get('Unique_ID')} - {card.get('Name')}")

        if updated_count > 0:
            with open(file_path, 'w') as f:
                json.dump(data, f, indent=2)

            print(f"  💾 {json_file}: Updated {updated_count} cards")
        else:
            print(f"  ⏭️  {json_file}: No updates needed")

    print("\n" + "=" * 60)
    print(f"✅ Complete! Updated {total_updated} enchanted cards")
    print("=" * 60)

if __name__ == "__main__":
    add_variant_field()
