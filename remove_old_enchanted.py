#!/usr/bin/env python3
"""
Remove enchanted cards with old numeric Unique_ID format
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

def remove_old_enchanted():
    """Remove enchanted cards with numeric Unique_IDs"""
    print("🧹 Removing old enchanted cards with numeric IDs")
    print("=" * 60)

    total_removed = 0

    for json_file in JSON_FILES:
        file_path = os.path.join(DATA_DIR, json_file)

        if not os.path.exists(file_path):
            continue

        with open(file_path, 'r') as f:
            data = json.load(f)

        original_count = len(data.get("cards", []))

        # Remove ALL enchanted cards to re-add with corrected names
        filtered_cards = []
        removed_count = 0

        for card in data.get("cards", []):
            # Remove all cards with Rarity "Enchanted"
            if card.get("Rarity") == "Enchanted":
                removed_count += 1
                total_removed += 1
                print(f"  ❌ Removing: {card.get('Unique_ID')} - {card.get('Name')}")
            else:
                filtered_cards.append(card)

        if removed_count > 0:
            data["cards"] = filtered_cards
            data["cardCount"] = len(filtered_cards)

            with open(file_path, 'w') as f:
                json.dump(data, f, indent=2)

            print(f"  ✅ {json_file}: Removed {removed_count} cards ({original_count} → {len(filtered_cards)})")
        else:
            print(f"  ⏭️  {json_file}: No old enchanted cards found")

    print("\n" + "=" * 60)
    print(f"✅ Complete! Removed {total_removed} old enchanted cards")
    print("=" * 60)

if __name__ == "__main__":
    remove_old_enchanted()
