#!/usr/bin/env python3
"""
Download complete Lorcana card data from LorcanaJSON.org and convert to app format.
Creates migration mapping to preserve user collections during data update.
"""

import urllib.request
import json
import os
import time
from typing import Dict, List, Any

# LorcanaJSON.org API endpoints
LORCANAJSON_API = "https://api.lorcast.com/v0"

# App data directory
DATA_DIR = "Inkwell Keeper/Data"

# Set name mapping (LorcanaJSON → App)
SET_NAME_MAP = {
    "The First Chapter": "The First Chapter",
    "Rise of the Floodborn": "Rise of the Floodborn",
    "Into the Inklands": "Into the Inklands",
    "Ursula's Return": "Ursula's Return",
    "Shimmering Skies": "Shimmering Skies",
    "Azurite Sea": "Azurite Sea",
    "Fabled": "Fabled",
    "Archazia's Island": "Archazia's Island",
    "Reign of Jafar": "Reign of Jafar",
    "Whispers in the Well": "Whispers in the Well",
    "Promo": "Promo Set 1",
}

# Set code mapping
SET_CODE_MAP = {
    "The First Chapter": "TFC",
    "Rise of the Floodborn": "ROF",
    "Into the Inklands": "ITI",
    "Ursula's Return": "TUR",
    "Shimmering Skies": "SSK",
    "Azurite Sea": "AZS",
    "Fabled": "FAB",
    "Archazia's Island": "ARI",
    "Reign of Jafar": "ROJ",
    "Whispers in the Well": "WIW",
    "Promo Set 1": "P1",
    "Promo Set 2": "P2",
    "Challenge Promo": "CP",
    "D23 Collection": "D23",
}

# Variant mapping
VARIANT_MAP = {
    "normal": "Normal",
    "foil": "Foil",
    "enchanted": "Enchanted",
    "promo": "Promo",
    "borderless": "Borderless",
    "epic": "Epic",
    "iconic": "Iconic",
}

def fetch_json(url: str) -> Any:
    """Fetch JSON data from URL"""
    print(f"📥 Fetching: {url}")
    try:
        with urllib.request.urlopen(url) as response:
            return json.loads(response.read())
    except Exception as e:
        print(f"❌ Error fetching {url}: {e}")
        return None

def convert_card_to_app_format(card: Dict) -> Dict:
    """Convert LorcanaJSON card format to app format"""

    # Get set info from nested object
    set_info = card.get("set", {})
    set_name = set_info.get("name", "")
    set_code_raw = set_info.get("code", "")

    # Map to app set code
    set_code = SET_CODE_MAP.get(set_name, set_code_raw)

    # Determine variant based on rarity
    rarity_raw = card.get("rarity", "").lower()
    variant_raw = "normal"

    if "enchanted" in rarity_raw:
        variant_raw = "enchanted"
    elif "epic" in rarity_raw:
        variant_raw = "epic"
    elif "iconic" in rarity_raw:
        variant_raw = "iconic"
    elif "promo" in set_name.lower() or "promo" in rarity_raw:
        variant_raw = "promo"

    variant = VARIANT_MAP.get(variant_raw, "Normal")

    # Get card number (comes as string like "001" or "195")
    collector_number = card.get("collector_number", "")
    card_num = None
    if collector_number:
        try:
            card_num = int(collector_number)
        except (ValueError, TypeError):
            # Handle non-numeric collector numbers (rare edge cases)
            card_num = None

    # Build uniqueId in format: SET_CODE-NUMBER
    unique_id = None
    if card_num and set_code:
        unique_id = f"{set_code}-{card_num:03d}"

    # Get card name with version/subtitle
    card_name = card.get("name", "")
    version = card.get("version", "")

    # Combine name with version if present (e.g., "Stitch - Carefree Surfer")
    full_name = card_name
    if version:
        full_name = f"{card_name} - {version}"

    # Build card ID
    name_part = full_name.replace(" ", "_").replace("-", "_").replace("'", "")
    card_id = f"{set_name.replace(' ', '_')}_{card_num or 0}_{name_part}"
    if variant != "Normal":
        card_id += f"_{variant}"

    # Get card text
    card_text = card.get("text", "")

    # Add flavor text if present
    flavor_text = card.get("flavor_text")
    if flavor_text:
        if card_text:
            card_text += f"\n\n{flavor_text}"
        else:
            card_text = flavor_text

    # Get image URL
    image_urls = card.get("image_uris", {})
    image_url = None
    if isinstance(image_urls, dict):
        # Try digital > large > small
        digital = image_urls.get("digital", {})
        if isinstance(digital, dict):
            image_url = digital.get("large") or digital.get("normal") or digital.get("small")
        if not image_url:
            image_url = image_urls.get("large") or image_urls.get("normal") or image_urls.get("small")

    # Fallback to unique_id based URL
    if not image_url and unique_id:
        suffix = "" if variant == "Normal" else f"-{variant_raw}"
        image_url = f"local://{unique_id}{suffix}"

    # Get type (comes as array like ["Action", "Song"])
    card_type = card.get("type", [])
    if isinstance(card_type, list):
        card_type = " - ".join(card_type)
    elif not card_type:
        card_type = ""

    # Convert rarity to proper case
    rarity = card.get("rarity", "Common")
    if isinstance(rarity, str):
        # Convert "Super_rare" to "Super Rare", "Enchanted" stays "Enchanted"
        rarity = rarity.replace("_", " ").title()

    # Get ink color
    ink_color = card.get("ink", "")

    # Build app-format card
    return {
        "id": card_id,
        "name": full_name,  # Use full name with version/subtitle
        "cost": card.get("cost"),
        "type": card_type,
        "rarity": rarity,
        "setName": set_name,
        "cardText": card_text,
        "imageUrl": image_url or "",
        "variant": variant,
        "cardNumber": card_num,
        "uniqueId": unique_id,
        "inkwell": card.get("inkwell", False),
        "strength": card.get("strength"),
        "willpower": card.get("willpower"),
        "lore": card.get("lore"),
        "franchise": "",  # Not in API response
        "inkColor": ink_color,
    }

def load_existing_cards() -> Dict[str, Dict]:
    """Load existing cards from app JSON files to build migration map"""
    existing = {}

    if not os.path.exists(DATA_DIR):
        return existing

    for filename in os.listdir(DATA_DIR):
        if not filename.endswith(".json"):
            continue

        filepath = os.path.join(DATA_DIR, filename)
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)

            for card in data.get("cards", []):
                # Create multiple lookup keys for migration
                card_name = card.get("name") or card.get("Name", "")
                set_name = card.get("setName") or card.get("Set_Name", "")
                unique_id = card.get("uniqueId") or card.get("Unique_ID", "")
                card_num = card.get("cardNumber") or card.get("Card_Num")

                if not card_name:
                    continue

                # Store by multiple keys for flexible matching
                if unique_id:
                    existing[f"uid:{unique_id}"] = card
                if card_name and set_name:
                    key = f"name:{card_name}|set:{set_name}"
                    existing[key] = card
                if card_num and set_name:
                    key = f"num:{card_num}|set:{set_name}"
                    existing[key] = card

        except Exception as e:
            print(f"⚠️  Error loading {filename}: {e}")

    return existing

def build_migration_map(old_cards: Dict[str, Dict], new_cards: List[Dict]) -> Dict:
    """Build mapping from old card IDs to new card IDs"""
    migration_map = {}

    for new_card in new_cards:
        new_id = new_card["id"]
        new_unique_id = new_card.get("uniqueId")
        new_name = new_card["name"]
        new_set = new_card["setName"]
        new_variant = new_card.get("variant", "Normal")
        new_num = new_card.get("cardNumber")

        # Try to find matching old card
        old_card = None
        old_id = None

        # Strategy 1: Match by uniqueId (most reliable)
        if new_unique_id:
            old_card = old_cards.get(f"uid:{new_unique_id}")
            if old_card:
                old_id = old_card.get("id")

        # Strategy 2: Match by name + set + variant
        if not old_card:
            key = f"name:{new_name}|set:{new_set}"
            old_card = old_cards.get(key)
            if old_card:
                old_id = old_card.get("id")

        # Strategy 3: Match by card number + set
        if not old_card and new_num:
            key = f"num:{new_num}|set:{new_set}"
            old_card = old_cards.get(key)
            if old_card:
                old_id = old_card.get("id")

        # Add to migration map
        if old_id:
            migration_map[old_id] = {
                "old_id": old_id,
                "new_id": new_id,
                "new_unique_id": new_unique_id,
                "name": new_name,
                "set": new_set,
                "variant": new_variant,
                "match_method": "uniqueId" if new_unique_id and f"uid:{new_unique_id}" in old_cards else "name+set"
            }

    return migration_map

def fetch_all_cards_from_api():
    """Fetch all cards from all sets using the Lorcast API"""
    all_cards = []

    # First, get all sets
    print("📦 Fetching all sets...")
    sets_url = f"{LORCANAJSON_API}/sets"
    sets_data = fetch_json(sets_url)
    if not sets_data:
        return None

    sets = sets_data.get("results", [])
    print(f"   Found {len(sets)} sets")
    print()

    # For each set, fetch all cards (including all variants/prints)
    for set_info in sets:
        set_code = set_info.get("code", "")
        set_name = set_info.get("name", "")

        print(f"📚 Fetching cards for: {set_name} ({set_code})...")

        # Use unique=prints to get all print variants (normal, foil, enchanted, etc.)
        cards_url = f"{LORCANAJSON_API}/cards/search?q=set:{set_code}&unique=prints"
        cards_data = fetch_json(cards_url)

        if cards_data:
            cards = cards_data.get("results", [])
            print(f"   ✅ Fetched {len(cards)} cards")
            all_cards.extend(cards)
        else:
            print(f"   ⚠️  Failed to fetch cards for {set_name}")

        # Small delay to be nice to the API
        time.sleep(0.5)

    # Also fetch Epic and Iconic cards (they're separate from normal prints)
    print()
    print("🌟 Fetching Epic cards...")
    epic_url = f"{LORCANAJSON_API}/cards/search?q=rarity:epic"
    epic_data = fetch_json(epic_url)
    if epic_data:
        epic_cards = epic_data.get("results", [])
        print(f"   ✅ Fetched {len(epic_cards)} Epic cards")
        all_cards.extend(epic_cards)

    time.sleep(0.5)

    print("🌟 Fetching Iconic cards...")
    iconic_url = f"{LORCANAJSON_API}/cards/search?q=rarity:iconic"
    iconic_data = fetch_json(iconic_url)
    if iconic_data:
        iconic_cards = iconic_data.get("results", [])
        print(f"   ✅ Fetched {len(iconic_cards)} Iconic cards")
        all_cards.extend(iconic_cards)

    return all_cards

def download_and_convert():
    """Main function to download and convert all card data"""
    print("=" * 60)
    print("Lorcana Card Data Download & Conversion")
    print("=" * 60)
    print()

    # Step 1: Load existing cards for migration mapping
    print("📚 Loading existing card data for migration...")
    existing_cards = load_existing_cards()
    print(f"   Found {len(existing_cards)} existing card entries")
    print()

    # Step 2: Fetch all cards from LorcanaJSON
    all_cards_data = fetch_all_cards_from_api()
    if not all_cards_data:
        print("❌ Failed to fetch card data from LorcanaJSON")
        return

    print()
    print(f"✅ Fetched {len(all_cards_data)} total cards from LorcanaJSON.org")
    print()

    # Step 3: Group cards by set
    cards_by_set = {}
    set_counts = {}

    for card in all_cards_data:
        # Convert to app format (extracts set info internally)
        app_card = convert_card_to_app_format(card)
        set_name = app_card["setName"]

        if not set_name:
            print(f"⚠️  Skipping card with no set name: {app_card.get('name')}")
            continue

        if set_name not in cards_by_set:
            cards_by_set[set_name] = []
            set_counts[set_name] = 0

        cards_by_set[set_name].append(app_card)
        set_counts[set_name] += 1

    print(f"📦 Organized into {len(cards_by_set)} sets:")
    for set_name, count in sorted(set_counts.items()):
        print(f"   • {set_name}: {count} cards")
    print()

    # Step 4: Write JSON files for each set
    print("💾 Writing set JSON files...")
    os.makedirs(DATA_DIR, exist_ok=True)

    all_new_cards = []

    for set_name, cards in sorted(cards_by_set.items()):
        set_code = SET_CODE_MAP.get(set_name, "UNK")
        filename = set_name.lower().replace(" ", "_").replace("'", "") + ".json"
        filepath = os.path.join(DATA_DIR, filename)

        # Deduplicate cards by ID (some API responses have duplicates)
        seen_ids = set()
        unique_cards = []
        for card in cards:
            card_id = card.get("id")
            if card_id not in seen_ids:
                seen_ids.add(card_id)
                unique_cards.append(card)

        # Sort cards by card number
        unique_cards.sort(key=lambda c: (c.get("cardNumber") or 0, c.get("variant", "")))

        set_data = {
            "setName": set_name,
            "setCode": set_code,
            "cardCount": len(unique_cards),
            "cards": unique_cards
        }

        with open(filepath, 'w') as f:
            json.dump(set_data, f, indent=2)

        print(f"   ✅ {filename} ({len(unique_cards)} cards)")
        all_new_cards.extend(unique_cards)

    print()

    # Step 5: Build migration mapping
    print("🔄 Building migration map...")
    migration_map = build_migration_map(existing_cards, all_new_cards)

    migration_file = os.path.join(DATA_DIR, "migration_map.json")
    with open(migration_file, 'w') as f:
        json.dump({
            "version": "1.0",
            "migration_date": "2025-11-22",
            "total_mappings": len(migration_map),
            "mappings": migration_map
        }, f, indent=2)

    print(f"   ✅ Created migration map with {len(migration_map)} card mappings")
    print(f"   📄 Saved to: {migration_file}")
    print()

    # Step 6: Generate summary report
    print("=" * 60)
    print("Summary")
    print("=" * 60)
    print(f"Total cards downloaded: {len(all_new_cards)}")
    print(f"Sets created: {len(cards_by_set)}")
    print(f"Migration mappings: {len(migration_map)}")

    # Count variants
    variant_counts = {}
    for card in all_new_cards:
        variant = card.get("variant", "Normal")
        variant_counts[variant] = variant_counts.get(variant, 0) + 1

    print()
    print("Variant breakdown:")
    for variant, count in sorted(variant_counts.items()):
        print(f"   • {variant}: {count}")

    # Count cards with missing images
    missing_images = sum(1 for c in all_new_cards if not c.get("imageUrl") or c["imageUrl"].startswith("local://"))
    print()
    print(f"Cards needing local images: {missing_images}")

    print()
    print("✅ Download and conversion complete!")
    print()

if __name__ == "__main__":
    download_and_convert()
