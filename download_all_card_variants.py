#!/usr/bin/env python3
"""
Download all Lorcana card art variants from Lorcast API
Matches existing naming convention: CODE-NNN.jpg, CODE-NNN-enchanted.jpg, etc.
"""

import urllib.request
import json
import os
import time
from pathlib import Path

# Base API URL
API_BASE = "https://api.lorcast.com/v0"

# Output directory
OUTPUT_DIR = "Inkwell Keeper/Resources/CardImages"

# Set code mapping (Lorcast code -> Your 3-letter code + directory name)
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
    "P1": ("P1", "promo_set_1"),
    "D1": ("D1", "challenge_promo"),
}

def download_image(url, output_path):
    """Download an image from URL to output path"""
    try:
        # Create directory if needed
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        # Download image
        urllib.request.urlretrieve(url, output_path)
        return True
    except Exception as e:
        print(f"  ❌ Failed to download: {e}")
        return False

def get_all_sets():
    """Fetch all available sets"""
    print("📦 Fetching all sets...")

    try:
        response = urllib.request.urlopen(f"{API_BASE}/sets")
        data = json.loads(response.read())
        sets = data.get("results", [])
        print(f"✅ Found {len(sets)} sets")
        return sets
    except Exception as e:
        print(f"❌ Failed to fetch sets: {e}")
        return []

def get_all_cards_for_set(set_code):
    """Fetch all cards for a specific set (including all variants)"""
    try:
        # Use unique=prints to get all print variants
        url = f"{API_BASE}/cards/search?q=set:{set_code}&unique=prints"
        response = urllib.request.urlopen(url)
        data = json.loads(response.read())
        return data.get("results", [])
    except Exception as e:
        print(f"  ❌ Failed to fetch cards for set {set_code}: {e}")
        return []

def get_variant_suffix(card):
    """Determine the variant suffix based on rarity"""
    rarity = card.get("rarity", "").lower()

    # Map rarities to variants
    # For normal cards, return empty string
    # For special variants, return suffix with dash
    if rarity == "enchanted":
        return "-enchanted"
    elif rarity == "promo":
        return "-promo"
    else:
        # Normal, foil variants are just the base file
        return ""

def convert_avif_to_jpg(input_path, output_path):
    """Convert AVIF to JPG (placeholder - will just download as-is for now)"""
    # For now, just copy the file
    # In future, you could add actual AVIF->JPG conversion
    return input_path

def download_all_cards():
    """Main function to download all card variants"""
    print("🎴 Starting Lorcana Card Art Download")
    print("=" * 60)

    # Get all sets
    sets = get_all_sets()

    if not sets:
        print("❌ No sets found. Exiting.")
        return

    total_downloaded = 0
    total_skipped = 0
    total_errors = 0

    for set_data in sets:
        lorcast_code = set_data.get("code", "")
        set_name = set_data.get("name", "Unknown")

        # Skip if we don't have mapping for this set
        if lorcast_code not in SET_MAPPING:
            print(f"\n⚠️  Skipping {set_name} (Code: {lorcast_code}) - No mapping defined")
            continue

        set_code, dir_name = SET_MAPPING[lorcast_code]

        print(f"\n📚 Processing Set: {set_name} (Code: {lorcast_code} -> {set_code})")
        print("-" * 60)

        # Fetch all cards for this set
        cards = get_all_cards_for_set(lorcast_code)
        print(f"  Found {len(cards)} cards (including variants)")

        for card in cards:
            card_name = card.get("name", "Unknown")
            collector_number = card.get("collector_number", "000")
            variant_suffix = get_variant_suffix(card)

            # Get image URL (use normal size)
            image_uris = card.get("image_uris", {}).get("digital", {})
            image_url = image_uris.get("normal") or image_uris.get("large")

            if not image_url:
                print(f"  ⚠️  No image URL for {card_name} #{collector_number}")
                total_errors += 1
                continue

            # Format filename to match existing convention
            # Normal: CODE-NNN.jpg
            # Variant: CODE-NNN-variant.jpg
            filename = f"{set_code}-{collector_number.zfill(3)}{variant_suffix}.jpg"
            output_path = os.path.join(OUTPUT_DIR, dir_name, filename)

            # Skip if already exists
            if os.path.exists(output_path):
                print(f"  ⏭️  Skipping (exists): {filename}")
                total_skipped += 1
                continue

            # Download image
            print(f"  ⬇️  Downloading: {filename}")

            # Download to temporary .avif file first
            temp_path = output_path.replace('.jpg', '.avif')
            if download_image(image_url, temp_path):
                # For now, just rename .avif to .jpg
                # In production, you'd convert AVIF->JPG here
                try:
                    os.rename(temp_path, output_path)
                    total_downloaded += 1
                    time.sleep(0.1)  # Rate limiting
                except Exception as e:
                    print(f"  ❌ Failed to rename: {e}")
                    total_errors += 1
            else:
                total_errors += 1

    print("\n" + "=" * 60)
    print(f"✅ Download Complete!")
    print(f"   Downloaded: {total_downloaded} images")
    print(f"   Skipped: {total_skipped} images")
    print(f"   Errors: {total_errors}")
    print("=" * 60)

if __name__ == "__main__":
    download_all_cards()
