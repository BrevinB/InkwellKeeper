#!/usr/bin/env python3
"""
Fetch enchanted cards from Lorcast API and add them to set JSON files
"""

import urllib.request
import json
import os
from datetime import datetime

API_BASE = "https://api.lorcast.com/v0"
DATA_DIR = "Inkwell Keeper/Data"

SET_MAPPING = {
    "1": ("the_first_chapter.json", "The First Chapter", "TFC"),
    "2": ("rise_of_the_floodborn.json", "Rise of the Floodborn", "ROF"),
    "3": ("into_the_inklands.json", "Into the Inklands", "ITI"),
    "4": ("ursulas_return.json", "Ursula's Return", "URS"),
    "5": ("shimmering_skies.json", "Shimmering Skies", "SSK"),
    "6": ("azurite_sea.json", "Azurite Sea", "AZS"),
    "7": ("fabled.json", "Fabled", "FAB"),
    "8": ("archazias_island.json", "Archazia's Island", "ARC"),
    "9": ("reign_of_jafar.json", "Reign of Jafar", "ROJ"),
    "10": ("whispers_in_the_well.json", "Whispers in the Well", "WIW"),
}

def get_enchanted_cards_for_set(set_code):
    """Fetch enchanted cards for a specific set"""
    try:
        url = f"{API_BASE}/cards/search?q=set:{set_code}+rarity:enchanted"
        response = urllib.request.urlopen(url)
        data = json.loads(response.read())
        return data.get("results", [])
    except Exception as e:
        print(f"  ❌ Failed to fetch enchanted cards for set {set_code}: {e}")
        return []

def lorcast_to_app_format(card, set_name, set_code, app_code):
    """Convert Lorcast card format to your app's format"""
    # Safely get list fields
    classifications = card.get("classifications")
    if not isinstance(classifications, list):
        classifications = []

    illustrators = card.get("illustrators")
    if not isinstance(illustrators, list):
        illustrators = []

    card_type = card.get("type")
    if not isinstance(card_type, list):
        card_type = []

    # Construct full card name (name + version)
    card_name = card.get("name", "")
    card_version = card.get("version")
    if card_version:
        full_name = f"{card_name} - {card_version}"
    else:
        full_name = card_name

    return {
        "Artist": ", ".join(illustrators),
        "Set_Name": set_name,
        "Classifications": ", ".join(classifications),
        "Date_Added": datetime.now().isoformat(),
        "Set_Num": card.get("set", {}).get("code", set_code),
        "Color": card.get("ink", ""),
        "Gamemode": "",
        "Franchise": card.get("franchise", ""),
        "Image": card.get("image_uris", {}).get("digital", {}).get("normal", ""),
        "Cost": card.get("cost", 0),
        "Inkable": card.get("inkwell", False),
        "Name": full_name,
        "Type": ", ".join(card_type),
        "Lore": card.get("lore"),
        "Rarity": card.get("rarity", "").replace("_", " ").title(),
        "Variant": "Enchanted",  # Set variant for Swift to recognize
        "Flavor_Text": card.get("flavor_text", "") or "",
        "Unique_ID": f"{app_code}-{str(card.get('collector_number', '000')).zfill(3)}",
        "Card_Num": int(card.get("collector_number", 0)) if str(card.get("collector_number", "")).isdigit() else 0,
        "Body_Text": card.get("text", ""),
        "Willpower": card.get("willpower"),
        "Date_Modified": datetime.now().strftime("%Y-%m-%d %H:%M:%S.0"),
        "Strength": card.get("strength"),
        "Set_ID": app_code
    }

def add_enchanted_cards():
    """Main function to add enchanted cards to JSON files"""
    print("🎴 Adding Enchanted Cards to Set JSON Files")
    print("=" * 60)

    total_added = 0

    for lorcast_code, (json_file, set_name, app_code) in SET_MAPPING.items():
        print(f"\n📚 Processing Set: {set_name} (Code: {lorcast_code} -> {app_code})")
        print("-" * 60)

        file_path = os.path.join(DATA_DIR, json_file)

        # Check if file exists
        if not os.path.exists(file_path):
            print(f"  ⚠️  Skipping - file not found: {json_file}")
            continue

        # Load existing JSON
        with open(file_path, 'r') as f:
            data = json.load(f)

        # Get existing card IDs to avoid duplicates
        existing_ids = {card.get("Unique_ID") for card in data.get("cards", [])}
        original_count = len(data.get("cards", []))

        # Fetch enchanted cards
        enchanted_cards = get_enchanted_cards_for_set(lorcast_code)
        print(f"  Found {len(enchanted_cards)} enchanted cards from API")

        # Convert and add new cards
        added_count = 0
        for lorcast_card in enchanted_cards:
            app_card = lorcast_to_app_format(lorcast_card, set_name, lorcast_code, app_code)

            if app_card["Unique_ID"] not in existing_ids:
                data["cards"].append(app_card)
                added_count += 1
                total_added += 1
                print(f"  ✅ Added: {app_card['Unique_ID']} - {app_card['Name']}")

        if added_count > 0:
            # Update card count
            data["cardCount"] = len(data["cards"])

            # Save updated JSON
            with open(file_path, 'w') as f:
                json.dump(data, f, indent=2)

            print(f"  💾 Saved {added_count} new cards (total: {original_count} → {len(data['cards'])})")
        else:
            print(f"  ⏭️  No new cards to add")

    print("\n" + "=" * 60)
    print(f"✅ Complete! Added {total_added} enchanted cards total")
    print("=" * 60)

if __name__ == "__main__":
    add_enchanted_cards()
