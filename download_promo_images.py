#!/usr/bin/env python3
"""
Download promo card images from Lorcast API
"""

import json
import urllib.request
import urllib.parse
import os
import time

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

def download_image(url, output_path):
    """Download an image from URL to output path"""
    try:
        with urllib.request.urlopen(url) as response:
            with open(output_path, 'wb') as f:
                f.write(response.read())
        return True
    except Exception as e:
        print(f"      ❌ Error downloading: {e}")
        return False

def download_promo_images():
    """Download all promo card images"""
    print("🎴 Downloading Promo Card Images\n")
    print("=" * 60)

    base_dir = "Inkwell Keeper/Resources/CardImages"
    total_downloaded = 0

    for set_code, (folder_name, set_name) in PROMO_SETS.items():
        print(f"\n📦 Processing {set_name} ({set_code})")
        print("-" * 60)

        # Create folder
        folder_path = os.path.join(base_dir, folder_name)
        os.makedirs(folder_path, exist_ok=True)
        print(f"   📁 Folder: {folder_path}")

        # Fetch cards
        cards = fetch_cards_by_set(set_code)

        if not cards:
            print(f"   ⚠️  Skipping {set_name} - no cards found")
            continue

        # Download images for each card
        downloaded = 0
        for card in cards:
            # Build card code from set and collector number
            collector_num = card.get('collector_number', '')
            card_name = card.get('name', 'Unknown')
            version = card.get('version', '')
            full_name = f"{card_name} - {version}" if version else card_name

            if not collector_num:
                print(f"   ⚠️  Skipping {full_name} - no collector number")
                continue

            # Construct card code (e.g., P1-001 or P1-25ja)
            # Try to format as numeric, but keep alphanumeric if needed
            try:
                card_code = f"{set_code}-{int(collector_num):03d}"
            except ValueError:
                # Collector number is alphanumeric (e.g., "25ja")
                card_code = f"{set_code}-{collector_num}"

            # Get image URL (prefer digital normal version)
            image_uris = card.get('image_uris', {})
            digital_uris = image_uris.get('digital', {})
            image_url = digital_uris.get('normal') or digital_uris.get('large') or digital_uris.get('small')

            if not image_url:
                print(f"   ⚠️  Skipping {full_name} - no image URL")
                continue

            # Determine file extension from URL
            ext = 'jpg'
            if '.png' in image_url.lower():
                ext = 'png'
            elif '.avif' in image_url.lower():
                ext = 'avif'

            # Download image
            output_file = os.path.join(folder_path, f"{card_code}.{ext}")

            if os.path.exists(output_file):
                print(f"   ⏭️  {card_code}: {full_name} (already exists)")
                downloaded += 1
            else:
                print(f"   ⬇️  {card_code}: {full_name}")
                if download_image(image_url, output_file):
                    print(f"      ✅ Saved to {card_code}.{ext}")
                    downloaded += 1
                    time.sleep(0.5)  # Rate limit

        print(f"\n   📊 {set_name}: {downloaded}/{len(cards)} images downloaded")
        total_downloaded += downloaded

    print("\n" + "=" * 60)
    print(f"✅ Download complete! Total images: {total_downloaded}")

if __name__ == "__main__":
    download_promo_images()
