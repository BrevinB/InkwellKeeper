#!/usr/bin/env python3
"""
Download all enchanted variant card images for Disney Lorcana
Saves images as {UNIQUE_ID}-enchanted.jpg in the appropriate set folder
"""

import urllib.request
import json
import os
import time
from pathlib import Path

# Set mappings
SET_FOLDERS = {
    "The First Chapter": "the_first_chapter",
    "Rise of the Floodborn": "rise_of_the_floodborn",
    "Into the Inklands": "into_the_inklands",
    "Ursula's Return": "ursulas_return",
    "Shimmering Skies": "shimmering_skies",
    "Azurite Sea": "azurite_sea",
}

# Base path to card images
BASE_PATH = Path(__file__).parent / "Inkwell Keeper" / "Resources" / "CardImages"

# Enchanted card numbers by set (cards numbered 205+)
ENCHANTED_CARDS = {
    "The First Chapter": list(range(205, 217)),  # 12 cards: 205-216
    "Rise of the Floodborn": list(range(205, 217)),  # 12 cards: 205-216
    "Into the Inklands": list(range(205, 223)),  # 18 cards: 205-222
    "Ursula's Return": list(range(205, 223)),  # 18 cards: 205-222
    "Shimmering Skies": list(range(205, 223)),  # 18 cards: 205-222
    "Azurite Sea": list(range(205, 223)),  # 18 cards: 205-222
}

def download_image(url, output_path):
    """Download an image from URL to output_path"""
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            if response.status == 200:
                with open(output_path, 'wb') as f:
                    f.write(response.read())
                return True
            else:
                print(f"  ✗ HTTP {response.status} for {url}")
                return False
    except Exception as e:
        print(f"  ✗ Error downloading {url}: {e}")
        return False

def load_card_data(set_name):
    """Load card data from JSON file"""
    set_folder = SET_FOLDERS.get(set_name)
    if not set_folder:
        return []

    json_file = Path(__file__).parent / "Inkwell Keeper" / "Data" / f"{set_folder}.json"
    if not json_file.exists():
        print(f"Warning: JSON file not found: {json_file}")
        return []

    with open(json_file, 'r') as f:
        data = json.load(f)
        return data.get('cards', [])

def construct_enchanted_url(base_url):
    """Construct enchanted variant URL from base card URL"""
    # Pattern: https://lorcana-api.com/images/card_name/subtitle/card_name-subtitle-large.png
    # Enchanted: https://lorcana-api.com/images/card_name/subtitle/card_name-subtitle-enchanted-large.png

    if "-large.png" in base_url:
        return base_url.replace("-large.png", "-enchanted-large.png")
    elif ".png" in base_url:
        return base_url.replace(".png", "-enchanted.png")
    elif ".jpg" in base_url:
        return base_url.replace(".jpg", "-enchanted.jpg")

    return base_url

def main():
    print("=" * 60)
    print("Disney Lorcana Enchanted Card Image Downloader")
    print("=" * 60)
    print()

    print("Fetching card data from API...")
    # Fetch all cards from API
    try:
        with urllib.request.urlopen("https://api.lorcana-api.com/cards/all?pagesize=2000", timeout=30) as response:
            all_cards = json.loads(response.read().decode())
    except Exception as e:
        print(f"✗ Failed to fetch cards from API: {e}")
        return

    print(f"✓ Fetched {len(all_cards)} cards from API\n")

    total_downloaded = 0
    total_failed = 0
    total_skipped = 0

    for set_name, card_numbers in ENCHANTED_CARDS.items():
        print(f"\n📦 Processing: {set_name}")
        print(f"   Expected enchanted cards: {len(card_numbers)}")

        # Get set folder
        set_folder = SET_FOLDERS.get(set_name)
        if not set_folder:
            print(f"   ⚠️  No folder mapping for {set_name}")
            continue

        # Create output directory
        output_dir = BASE_PATH / set_folder
        if not output_dir.exists():
            print(f"   ⚠️  Directory doesn't exist: {output_dir}")
            continue

        # Filter cards for this set
        set_cards = [c for c in all_cards if c.get('Set_Name') == set_name]

        # Find cards with matching numbers
        for card_num in card_numbers:
            # Find card by card number
            matching_cards = [c for c in set_cards if c.get('Card_Num') == card_num]

            if not matching_cards:
                print(f"   ⚠️  Card #{card_num} not found in API data")
                total_failed += 1
                continue

            card = matching_cards[0]
            unique_id = card.get('Unique_ID')
            card_name = card.get('Name', 'Unknown')
            base_image_url = card.get('Image', '')

            if not unique_id:
                print(f"   ⚠️  No Unique_ID for card #{card_num}")
                total_failed += 1
                continue

            # Construct output filename
            output_filename = f"{unique_id}-enchanted.jpg"
            output_path = output_dir / output_filename

            # Skip if already exists
            if output_path.exists():
                print(f"   ⏭  {unique_id}: {card_name} (already exists)")
                total_skipped += 1
                continue

            # Construct enchanted URL
            enchanted_url = construct_enchanted_url(base_image_url)

            print(f"   ⬇️  {unique_id}: {card_name}")
            print(f"      {enchanted_url}")

            # Download
            if download_image(enchanted_url, output_path):
                print(f"   ✓  Saved to {output_filename}")
                total_downloaded += 1
            else:
                total_failed += 1

            # Be nice to the server
            time.sleep(0.5)

    # Summary
    print("\n" + "=" * 60)
    print("Download Summary:")
    print(f"  ✓ Downloaded: {total_downloaded}")
    print(f"  ⏭  Skipped (already exist): {total_skipped}")
    print(f"  ✗ Failed: {total_failed}")
    print("=" * 60)

if __name__ == "__main__":
    main()
