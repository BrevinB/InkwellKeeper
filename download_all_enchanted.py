#!/usr/bin/env python3
"""
Download ALL enchanted card images from Lorcast API
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

        # Find the non-enchanted version
        for card in results:
            if card.get("rarity", "").lower() != "enchanted":
                return card

        return None
    except Exception as e:
        print(f"  ❌ Failed to find normal version: {e}")
        return None

def download_image(url, output_path):
    """Download an image from URL"""
    try:
        # Get the image data
        response = urllib.request.urlopen(url)
        image_data = response.read()

        # Write to file
        with open(output_path, 'wb') as f:
            f.write(image_data)

        return True
    except Exception as e:
        print(f"    ❌ Download failed: {e}")
        return False

def download_all_enchanted():
    """Download all enchanted card images"""
    print("🎨 Downloading ALL Enchanted Card Images")
    print("=" * 80)

    total_downloaded = 0
    total_skipped = 0
    total_failed = 0

    for lorcast_code, (app_code, folder_name) in SET_MAPPING.items():
        print(f"\n📚 Processing {folder_name} ({app_code})")
        print("-" * 80)

        # Get enchanted cards
        enchanted_cards = get_enchanted_cards_for_set(lorcast_code)
        print(f"  Found {len(enchanted_cards)} enchanted cards")

        for enchanted in enchanted_cards:
            enchanted_num = enchanted.get("collector_number")
            enchanted_name = enchanted.get("name")
            enchanted_version = enchanted.get("version")
            full_name = f"{enchanted_name} - {enchanted_version}" if enchanted_version else enchanted_name

            # Find normal version to get the correct collector number
            normal = get_normal_card_for_enchanted(enchanted, lorcast_code)

            if not normal:
                print(f"  ⚠️  No normal version found for {full_name}")
                total_failed += 1
                continue

            normal_num = normal.get("collector_number")

            # Use the NORMAL collector number for the filename
            enchanted_id = f"{app_code}-{str(normal_num).zfill(3)}-enchanted"

            # Check if already exists
            output_dir = os.path.join(IMAGE_DIR, folder_name)
            os.makedirs(output_dir, exist_ok=True)

            output_path = os.path.join(output_dir, f"{enchanted_id}.jpg")

            if os.path.exists(output_path):
                print(f"  ⏭️  {enchanted_id}.jpg already exists")
                total_skipped += 1
                continue

            # Get image URL
            image_url = enchanted.get("image")
            if not image_url:
                print(f"  ❌ No image URL for {full_name}")
                total_failed += 1
                continue

            # Download image
            print(f"  📥 Downloading {enchanted_id}.jpg ({full_name})")
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
    download_all_enchanted()
