#!/usr/bin/env python3
"""
Create JSON data files for promo sets from Lorcast API
"""

import json
import urllib.request

# Promo set mappings
PROMO_SETS = {
    "P1": ("promo_set_1", "Promo Set 1"),
    "P2": ("promo_set_2", "Promo Set 2"),
    "cp": ("challenge_promo", "Challenge Promo"),
    "D23": ("d23_collection", "D23 Collection")
}

def fetch_cards_by_set(set_code):
    """Fetch all cards in a specific set from the Lorcast API"""
    print(f"\n🔍 Fetching {set_code} cards...")

    try:
        url = f"https://api.lorcast.com/v0/sets/{set_code}/cards"
        print(f"   URL: {url}")

        with urllib.request.urlopen(url) as response:
            cards = json.loads(response.read())

            if isinstance(cards, list):
                print(f"   ✅ Found {len(cards)} cards")
                return cards
            else:
                print(f"   ❌ Unexpected response format")
                return []

    except Exception as e:
        print(f"   ❌ Error fetching cards: {e}")
        return []

def convert_lorcast_card(card, set_name, set_code):
    """Convert Lorcast API card format to app's format"""

    # Get collector number and build card code
    collector_num = card.get('collector_number', '')
    try:
        card_code = f"{set_code}-{int(collector_num):03d}"
    except ValueError:
        card_code = f"{set_code}-{collector_num}"

    # Get version for full name
    version = card.get('version', '')

    # Build the card object in app format
    app_card = {
        "id": f"{set_name.replace(' ', '_')}_{collector_num}_{card.get('name', '').replace(' ', '_')}",
        "name": card.get('name', ''),
        "cost": card.get('cost', 0),
        "type": card['type'][0] if card.get('type') else '',
        "rarity": card.get('rarity', ''),
        "setName": set_name,
        "cardText": card.get('text', ''),
        "imageUrl": card.get('image_uris', {}).get('digital', {}).get('normal', ''),
        "variant": "Normal",
        "cardNumber": int(collector_num) if collector_num.isdigit() else None,
        "uniqueId": card_code,
        "inkwell": card.get('inkwell', False),
        "strength": card.get('strength'),
        "willpower": card.get('willpower'),
        "lore": card.get('lore'),
        "franchise": "",  # Not provided by API
        "inkColor": card.get('ink', '')
    }

    return app_card

def create_promo_json_files():
    """Create JSON files for all promo sets"""
    print("🎴 Creating Promo Set JSON Files\n")
    print("=" * 60)

    for set_code, (file_id, set_name) in PROMO_SETS.items():
        print(f"\n📦 Processing {set_name} ({set_code})")
        print("-" * 60)

        # Fetch cards from API
        cards = fetch_cards_by_set(set_code)

        if not cards:
            print(f"   ⚠️  Skipping {set_name} - no cards found")
            continue

        # Convert cards to app format
        converted_cards = []
        for card in cards:
            try:
                app_card = convert_lorcast_card(card, set_name, set_code)
                converted_cards.append(app_card)
            except Exception as e:
                print(f"   ⚠️  Error converting card: {e}")
                continue

        # Create the JSON structure
        set_data = {
            "setName": set_name,
            "setCode": set_code,
            "cardCount": len(converted_cards),
            "cards": converted_cards
        }

        # Write to file
        output_file = f"Inkwell Keeper/Data/{file_id}.json"
        with open(output_file, 'w') as f:
            json.dump(set_data, f, indent=2)

        print(f"   ✅ Created {output_file} with {len(converted_cards)} cards")

    print("\n" + "=" * 60)
    print("✅ All promo set JSON files created!")

if __name__ == "__main__":
    create_promo_json_files()
