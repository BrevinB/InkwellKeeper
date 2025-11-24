#!/usr/bin/env python3
"""
Script to add Enchanted/Epic/Iconic cards as separate entries in set JSON files.
These are separate cards with their own collector numbers, not just variants.
"""

import json
import os

# Sets that have enchanted cards
SETS_WITH_ENCHANTED = {
    "the_first_chapter": {"code": "TFC", "enchanted_range": range(201, 213)},  # 201-212
    "rise_of_the_floodborn": {"code": "ROF", "enchanted_range": range(205, 217)},  # 205-216
    "into_the_inklands": {"code": "ITI", "enchanted_range": range(205, 217)},  # 205-216
    "ursulas_return": {"code": "TUR", "enchanted_range": range(205, 217)},  # 205-216
    "shimmering_skies": {"code": "SSK", "enchanted_range": range(205, 217)},  # 205-216
    "azurite_sea": {"code": "AZS", "enchanted_range": range(205, 217)},  # 205-216
}

def add_enchanted_cards(json_file):
    """Add enchanted card entries to a set JSON file"""

    # Get set info
    filename = os.path.basename(json_file)
    set_key = filename.replace(".json", "")

    if set_key not in SETS_WITH_ENCHANTED:
        print(f"Skipping {set_key} - no enchanted cards")
        return

    set_info = SETS_WITH_ENCHANTED[set_key]
    set_code = set_info["code"]

    # Load existing JSON
    with open(json_file, 'r') as f:
        data = json.load(f)

    # Find cards that have enchanted variants
    enchanted_to_add = []

    for card in data.get("cards", []):
        card_num = card.get("Card_Num")
        if not card_num:
            continue

        # Check if this card has an enchanted variant
        card_variants = card.get("Card_Variants", "")
        if "enchanted" in card_variants.lower():
            # Create enchanted version
            enchanted_card = card.copy()

            # Update fields for enchanted version
            enchanted_num = 200 + card_num  # Enchanted cards are typically 200+ the normal number
            enchanted_card["Card_Num"] = enchanted_num
            enchanted_card["uniqueId"] = f"{set_code}-{enchanted_num:03d}"
            enchanted_card["Unique_ID"] = f"{set_code}-{enchanted_num:03d}"
            enchanted_card["variant"] = "Enchanted"
            enchanted_card["Rarity"] = "Enchanted"

            # Generate new ID
            name_part = card["Name"].replace(" ", "_").replace("-", "_").replace("'", "")
            enchanted_card["id"] = f"{set_key}_{enchanted_num}_{name_part}_Enchanted"

            # Update image URL to point to enchanted image
            enchanted_card["imageUrl"] = f"local://{set_code}-{enchanted_num:03d}"
            enchanted_card["Image"] = f"local://{set_code}-{enchanted_num:03d}"

            print(f"  Adding enchanted: {card['Name']} ({enchanted_num})")
            enchanted_to_add.append(enchanted_card)

    # Add enchanted cards to the list
    if enchanted_to_add:
        data["cards"].extend(enchanted_to_add)
        data["cardCount"] = len(data["cards"])

        # Write back to file
        with open(json_file, 'w') as f:
            json.dump(data, f, indent=2)

        print(f"✅ Added {len(enchanted_to_add)} enchanted cards to {set_key}")
    else:
        print(f"No enchanted cards to add for {set_key}")

# Main execution
data_dir = "Inkwell Keeper/Data"

for set_key in SETS_WITH_ENCHANTED.keys():
    json_file = os.path.join(data_dir, f"{set_key}.json")
    if os.path.exists(json_file):
        print(f"\nProcessing {set_key}...")
        add_enchanted_cards(json_file)
    else:
        print(f"⚠️  File not found: {json_file}")
