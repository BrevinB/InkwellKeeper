#!/usr/bin/env python3
"""
Fetch promo cards from Lorcast API and create promo set JSON files
"""

import json
import urllib.request
import urllib.parse
import time

# Lorcast API set codes for promos
PROMO_SETS = {
    "P1": {
        "id": "promo_set_1",
        "name": "Promo Set 1",
        "setCode": "P1",
        "description": "First wave of promotional cards from various events"
    },
    "P2": {
        "id": "promo_set_2",
        "name": "Promo Set 2",
        "setCode": "P2",
        "description": "Second wave of promotional cards from various events"
    },
    "cp": {
        "id": "challenge_promo",
        "name": "Challenge Promo",
        "setCode": "CP",
        "description": "Special promotional cards from Lorcana Challenge events"
    },
    "D23": {
        "id": "d23_collection",
        "name": "D23 Collection",
        "setCode": "D23",
        "description": "Exclusive cards from the D23 Disney fan event"
    }
}

def fetch_cards_for_set(set_code):
    """Fetch all cards for a given set from Lorcast API"""
    print(f"\n🔍 Fetching cards for set: {set_code}")

    url = f"https://api.lorcast.com/v0/cards?set={set_code}"
    print(f"   URL: {url}")

    try:
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read())
            cards = data.get('results', [])
            print(f"   ✅ Found {len(cards)} cards")
            return cards
    except Exception as e:
        print(f"   ❌ Error fetching cards: {e}")
        return []

def convert_lorcast_card_to_app_format(card):
    """Convert Lorcast API card format to app's format"""

    # Map Lorcast set codes to app set names
    set_code_to_name = {
        "P1": "Promo Set 1",
        "P2": "Promo Set 2",
        "cp": "Challenge Promo",
        "D23": "D23 Collection"
    }

    # Get the set name
    set_code = card.get('set_code', '')
    set_name = set_code_to_name.get(set_code, f"Unknown Set ({set_code})")

    # Build the card object in app format
    app_card = {
        "id": f"{card.get('set_code', '')}_{card.get('number', 0)}_{card.get('name', '').replace(' ', '_')}",
        "name": card.get('name', ''),
        "cost": card.get('cost', 0),
        "type": card.get('type', ''),
        "rarity": card.get('rarity', ''),
        "setName": set_name,
        "cardText": card.get('body', ''),
        "imageUrl": card.get('image_urls', {}).get('normal', {}).get('digital', ''),
        "variant": "Normal",
        "cardNumber": card.get('number'),
        "uniqueId": card.get('code', ''),
        "inkwell": card.get('inkwell', False),
        "strength": card.get('strength'),
        "willpower": card.get('willpower'),
        "lore": card.get('lore'),
        "franchise": card.get('franchise_name', ''),
        "inkColor": card.get('ink', '')
    }

    return app_card

def create_promo_json_file(set_info, cards):
    """Create a JSON file for the promo set"""
    output_file = f"Inkwell Keeper/Data/{set_info['id']}.json"

    # Convert cards to app format
    converted_cards = [convert_lorcast_card_to_app_format(card) for card in cards]

    # Create the JSON structure
    set_data = {
        "setName": set_info["name"],
        "setCode": set_info["setCode"],
        "cards": converted_cards
    }

    # Write to file
    with open(output_file, 'w') as f:
        json.dump(set_data, f, indent=2)

    print(f"✅ Created {output_file} with {len(converted_cards)} cards")
    return len(converted_cards)

def main():
    print("🎴 Fetching Promo Cards from Lorcast API\n")
    print("=" * 60)

    for set_code, set_info in PROMO_SETS.items():
        print(f"\n📦 Processing {set_info['name']} ({set_code})")
        print("-" * 60)

        # Fetch cards from API
        cards = fetch_cards_for_set(set_code)

        if cards:
            # Create JSON file
            card_count = create_promo_json_file(set_info, cards)
            set_info['cardCount'] = card_count
        else:
            print(f"⚠️  No cards found for {set_info['name']}")
            set_info['cardCount'] = 0

        # Rate limit
        time.sleep(1)

    print("\n" + "=" * 60)
    print("✅ Promo card data files created!")
    print("\nSet summary:")
    for set_code, set_info in PROMO_SETS.items():
        print(f"   • {set_info['name']}: {set_info.get('cardCount', 0)} cards")

if __name__ == "__main__":
    main()
