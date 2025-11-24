#!/usr/bin/env python3
"""
Download Epic and Iconic card images from Lorcast API
"""

import urllib.request
import urllib.parse
import json
import os

API_BASE = "https://api.lorcast.com/v0"
IMAGE_DIR = "Inkwell Keeper/Resources/CardImages"

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

def get_special_cards_for_set(set_code, rarity_type):
    """Fetch epic/iconic cards for a specific set"""
    try:
        url = f"{API_BASE}/cards/search?q=set:{set_code}+rarity:{rarity_type}"
        response = urllib.request.urlopen(url)
        data = json.loads(response.read())
        return data.get("results", [])
    except Exception as e:
        print(f"  ❌ Failed to fetch {rarity_type} cards for set {set_code}: {e}")
        return []

def get_normal_card_for_special(special_card, set_code):
    """Find the normal version of an epic/iconic card"""
    card_name = special_card.get("name")
    card_version = special_card.get("version")

    try:
        # Search by name and version in the same set
        if card_version:
            search_query = f'set:{set_code} name:"{card_name}" version:"{card_version}"'
        else:
            search_query = f'set:{set_code} name:"{card_name}"'

        encoded_query = urllib.parse.quote(search_query)
        url = f"{API_BASE}/cards/search?q={encoded_query}"
        response = urllib.request.urlopen(url)
        data = json.loads(response.read())
        results = data.get("results", [])

        # Find the non-epic/iconic version (usually Rare, Super Rare, or Legendary)
        for card in results:
            rarity = card.get("rarity", "").lower()
            if rarity not in ["epic", "iconic", "enchanted"]:
                return card

        return None
    except Exception as e:
        print(f"  ❌ Failed to find normal version: {e}")
        return None

def download_image(url, output_path):
    """Download an image from URL"""
    try:
        response = urllib.request.urlopen(url)
        image_data = response.read()

        with open(output_path, 'wb') as f:
            f.write(image_data)

        return True
    except Exception as e:
        print(f"    ❌ Download failed: {e}")
        return False

def download_all_special_variants():
    """Download all epic and iconic card images"""
    print("🎨 Downloading Epic and Iconic Card Images")
    print("=" * 80)

    total_downloaded = 0
    total_skipped = 0
    total_failed = 0

    for variant_type in ["epic", "iconic"]:
        print(f"\n{'='*80}")
        print(f"Processing {variant_type.upper()} cards")
        print(f"{'='*80}")

        for lorcast_code, (app_code, folder_name) in SET_MAPPING.items():
            print(f"\n📚 {folder_name} ({app_code})")
            print("-" * 80)

            # Get special cards
            special_cards = get_special_cards_for_set(lorcast_code, variant_type)
            print(f"  Found {len(special_cards)} {variant_type} cards")

            for special in special_cards:
                special_num = special.get("collector_number")
                special_name = special.get("name")
                special_version = special.get("version")
                full_name = f"{special_name} - {special_version}" if special_version else special_name

                # Find normal version to get the correct collector number
                normal = get_normal_card_for_special(special, lorcast_code)

                if not normal:
                    print(f"  ⚠️  No normal version found for {full_name}")
                    total_failed += 1
                    continue

                normal_num = normal.get("collector_number")

                # Use the NORMAL collector number for the filename
                special_id = f"{app_code}-{str(normal_num).zfill(3)}-{variant_type}"

                # Check if already exists
                output_dir = os.path.join(IMAGE_DIR, folder_name)
                os.makedirs(output_dir, exist_ok=True)

                output_path = os.path.join(output_dir, f"{special_id}.jpg")

                if os.path.exists(output_path):
                    print(f"  ⏭️  {special_id}.jpg already exists")
                    total_skipped += 1
                    continue

                # Get image URL
                image_url = special.get("image")
                if not image_url:
                    print(f"  ❌ No image URL for {full_name}")
                    total_failed += 1
                    continue

                # Download image
                print(f"  📥 Downloading {special_id}.jpg ({full_name})")
                if download_image(image_url, output_path):
                    print(f"    ✅ Downloaded")
                    total_downloaded += 1
                else:
                    total_failed += 1

    print("\n" + "=" * 80)
    print(f"✅ Downloaded: {total_downloaded}")
    print(f"⏭️  Skipped: {total_skipped}")
    if total_failed > 0:
        print(f"❌ Failed: {total_failed}")
    print("=" * 80)

if __name__ == "__main__":
    download_all_special_variants()
