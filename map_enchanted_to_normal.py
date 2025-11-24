#!/usr/bin/env python3
"""
Map enchanted cards to their normal versions and create a mapping file
"""

import urllib.request
import urllib.parse
import json

API_BASE = "https://api.lorcast.com/v0"

SET_MAPPING = {
    "1": ("TFC", "the_first_chapter"),
    "2": ("ROF", "rise_of_the_floodborn"),
    "3": ("ITI", "into_the_inklands"),
    "4": ("URS", "ursulas_return"),
    "5": ("SSK", "shimmering_skies"),
    "6": ("AZS", "azurite_sea"),
    "7": ("FAB", "fabled"),
    "8": ("ARC", "archazias_island"),
    "9": ("ROJ", "reign_of_jafar"),
    "10": ("WIW", "whispers_in_the_well"),
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

def get_normal_card_for_enchanted(enchanted_card, set_code):
    """Find the normal version of an enchanted card"""
    card_name = enchanted_card.get("name")
    card_version = enchanted_card.get("version")

    # Search for normal version of this card
    try:
        # Search by name and version in the same set
        if card_version:
            search_query = f'set:{set_code} name:"{card_name}" version:"{card_version}"'
        else:
            search_query = f'set:{set_code} name:"{card_name}"'

        # URL encode the query
        encoded_query = urllib.parse.quote(search_query)
        url = f"{API_BASE}/cards/search?q={encoded_query}"
        response = urllib.request.urlopen(url)
        data = json.loads(response.read())
        results = data.get("results", [])

        # Find the non-enchanted version
        for card in results:
            if card.get("rarity", "").lower() != "enchanted":
                return card

        return None
    except Exception as e:
        print(f"  ❌ Failed to find normal version: {e}")
        return None

def create_mapping():
    """Create mapping of enchanted to normal cards"""
    print("🗺️  Creating Enchanted → Normal Card Mapping")
    print("=" * 80)

    mapping = {}

    for lorcast_code, (app_code, folder_name) in SET_MAPPING.items():
        print(f"\n📚 Processing {folder_name} (Code: {lorcast_code} -> {app_code})")
        print("-" * 80)

        # Get enchanted cards
        enchanted_cards = get_enchanted_cards_for_set(lorcast_code)
        print(f"  Found {len(enchanted_cards)} enchanted cards")

        set_mapping = []

        for enchanted in enchanted_cards:
            enchanted_num = enchanted.get("collector_number")
            enchanted_name = enchanted.get("name")
            enchanted_version = enchanted.get("version")
            full_name = f"{enchanted_name} - {enchanted_version}" if enchanted_version else enchanted_name

            # Find normal version
            normal = get_normal_card_for_enchanted(enchanted, lorcast_code)

            if normal:
                normal_num = normal.get("collector_number")
                normal_rarity = normal.get("rarity", "").title()

                set_mapping.append({
                    "name": full_name,
                    "enchanted_number": enchanted_num,
                    "normal_number": normal_num,
                    "normal_rarity": normal_rarity,
                    "enchanted_id": f"{app_code}-{str(enchanted_num).zfill(3)}",
                    "normal_id": f"{app_code}-{str(normal_num).zfill(3)}"
                })

                print(f"  ✅ {app_code}-{str(enchanted_num).zfill(3)} → {app_code}-{str(normal_num).zfill(3)} ({full_name} - {normal_rarity})")
            else:
                print(f"  ⚠️  No normal version found for {full_name} (#{enchanted_num})")

        mapping[app_code] = {
            "folder": folder_name,
            "cards": set_mapping
        }

    # Save mapping
    with open("enchanted_to_normal_mapping.json", "w") as f:
        json.dump(mapping, f, indent=2)

    print("\n" + "=" * 80)
    print("✅ Mapping saved to enchanted_to_normal_mapping.json")
    print("=" * 80)

if __name__ == "__main__":
    create_mapping()
