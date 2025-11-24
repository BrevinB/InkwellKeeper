#!/usr/bin/env python3
"""
Complete image download and standardization script.
Downloads all missing images (Epic/Iconic) and standardizes naming to match JSON format.
"""

import urllib.request
import json
import os
import shutil
from pathlib import Path

# Directories
DATA_DIR = "Inkwell Keeper/Data"
IMAGE_DIR = "Inkwell Keeper/Resources/CardImages"

# Set code mapping (numeric API code -> letter code)
SET_CODE_MAP = {
    "1": "TFC",
    "2": "ROF",
    "3": "ITI",
    "4": "TUR",
    "5": "SSK",
    "6": "AZS",
    "7": "ARI",
    "8": "ROJ",
    "9": "FAB",
    "10": "WIW",
    "P1": "P1",
    "P2": "P2",
    "cp": "CP",
    "D23": "D23"
}

SET_FOLDER_MAP = {
    "TFC": "the_first_chapter",
    "ROF": "rise_of_the_floodborn",
    "ITI": "into_the_inklands",
    "TUR": "ursulas_return",
    "SSK": "shimmering_skies",
    "AZS": "azurite_sea",
    "ARI": "archazias_island",
    "ROJ": "reign_of_jafar",
    "FAB": "fabled",
    "WIW": "whispers_in_the_well",
    "P1": "promo_set_1",
    "P2": "promo_set_2",
    "CP": "challenge_promo",
    "D23": "d23_collection"
}

def download_image(url, output_path):
    """Download image from URL"""
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        urllib.request.urlretrieve(url, output_path)
        return True
    except Exception as e:
        print(f"  ❌ Failed: {e}")
        return False

def download_missing_images():
    """Download all missing Epic/Iconic images from JSON data"""
    print("=" * 70)
    print("DOWNLOADING MISSING IMAGES")
    print("=" * 70)
    print()

    downloaded = 0
    skipped = 0
    failed = 0

    # Process each JSON file
    for filename in sorted(os.listdir(DATA_DIR)):
        if not filename.endswith('.json') or filename == 'migration_map.json':
            continue

        filepath = os.path.join(DATA_DIR, filename)

        with open(filepath, 'r') as f:
            data = json.load(f)

        set_name = data.get('setName', '')
        set_code = data.get('setCode', '')
        folder = SET_FOLDER_MAP.get(set_code, '')

        if not folder:
            continue

        print(f"📦 {set_name} ({set_code})...")

        for card in data.get('cards', []):
            card_num = card.get('cardNumber')
            variant = card.get('variant', 'Normal').lower()
            image_url = card.get('imageUrl', '')
            unique_id = card.get('uniqueId', '')

            if not card_num or not unique_id:
                continue

            # Determine suffix
            if variant == 'normal':
                suffix = ''
            elif variant == 'foil':
                suffix = ''  # Foil uses same image as normal
            else:
                suffix = f"-{variant}"

            # Target filename (standardized format)
            target_filename = f"{unique_id}{suffix}.avif"
            target_path = os.path.join(IMAGE_DIR, folder, target_filename)

            # Check if already exists
            if os.path.exists(target_path):
                skipped += 1
                continue

            # Check for old naming format
            old_num = card_num
            old_filename = f"{set_code.lower()}-{old_num:03d}{suffix}.avif"
            old_path = os.path.join(IMAGE_DIR, folder, old_filename)

            if os.path.exists(old_path):
                # Just rename it
                shutil.move(old_path, target_path)
                skipped += 1
                continue

            # Need to download
            if image_url and image_url.startswith('http'):
                print(f"  ⬇️  {target_filename}")
                if download_image(image_url, target_path):
                    downloaded += 1
                else:
                    failed += 1
            else:
                # No URL, mark as missing
                failed += 1

    print()
    print(f"✅ Downloaded: {downloaded}")
    print(f"⏭  Skipped (exist): {skipped}")
    print(f"❌ Failed: {failed}")
    print()

def standardize_image_names():
    """Rename all images to match JSON naming scheme"""
    print("=" * 70)
    print("STANDARDIZING IMAGE NAMES")
    print("=" * 70)
    print()

    renamed = 0
    skipped = 0

    # Load all JSON data to build mapping
    name_mapping = {}  # old_name -> new_name

    for filename in sorted(os.listdir(DATA_DIR)):
        if not filename.endswith('.json') or filename == 'migration_map.json':
            continue

        filepath = os.path.join(DATA_DIR, filename)

        with open(filepath, 'r') as f:
            data = json.load(f)

        set_code = data.get('setCode', '')
        folder = SET_FOLDER_MAP.get(set_code, '')

        if not folder:
            continue

        # Get numeric API code for this set
        api_code = None
        for k, v in SET_CODE_MAP.items():
            if v == set_code:
                api_code = k
                break

        if not api_code:
            continue

        for card in data.get('cards', []):
            card_num = card.get('cardNumber')
            variant = card.get('variant', 'Normal').lower()
            unique_id = card.get('uniqueId', '')

            if not card_num or not unique_id:
                continue

            # Determine suffix
            if variant in ['normal', 'foil']:
                suffix = ''
                old_suffix = '-normal'
            else:
                suffix = f"-{variant}"
                old_suffix = f"-{variant}"

            # Old naming patterns
            old_names = [
                f"{api_code}-{card_num:03d}{old_suffix}.avif",
                f"{api_code}-{card_num}{old_suffix}.avif",
                f"{set_code}-{card_num:03d}{old_suffix}.avif",
            ]

            # New standardized name
            new_name = f"{unique_id}{suffix}.avif"

            for old_name in old_names:
                old_path = os.path.join(IMAGE_DIR, folder, old_name)
                new_path = os.path.join(IMAGE_DIR, folder, new_name)

                if os.path.exists(old_path) and not os.path.exists(new_path):
                    print(f"  📝 {old_name} → {new_name}")
                    shutil.move(old_path, new_path)
                    renamed += 1
                    break

    print()
    print(f"✅ Renamed: {renamed}")
    print(f"⏭  Skipped: {skipped}")
    print()

def convert_avif_to_jpg():
    """Convert all AVIF images to JPG using Python Pillow"""
    print("=" * 70)
    print("CONVERTING AVIF TO JPG")
    print("=" * 70)
    print()

    try:
        from PIL import Image
        has_pillow = True
    except ImportError:
        print("⚠️  Pillow not installed. Skipping AVIF->JPG conversion.")
        print("   Install with: pip3 install Pillow pillow-avif-plugin")
        print("   AVIF images will work fine in iOS - conversion is optional.")
        has_pillow = False
        return

    if not has_pillow:
        return

    converted = 0
    failed = 0

    for folder in sorted(os.listdir(IMAGE_DIR)):
        folder_path = os.path.join(IMAGE_DIR, folder)

        if not os.path.isdir(folder_path):
            continue

        print(f"📁 {folder}...")

        for filename in os.listdir(folder_path):
            if not filename.endswith('.avif'):
                continue

            avif_path = os.path.join(folder_path, filename)
            jpg_filename = filename.replace('.avif', '.jpg')
            jpg_path = os.path.join(folder_path, jpg_filename)

            if os.path.exists(jpg_path):
                continue

            try:
                img = Image.open(avif_path)
                img.convert('RGB').save(jpg_path, 'JPEG', quality=95)
                # Keep AVIF as backup, or delete it
                # os.remove(avif_path)
                converted += 1
            except Exception as e:
                failed += 1
                print(f"  ❌ Failed to convert {filename}: {e}")

    print()
    print(f"✅ Converted: {converted}")
    print(f"❌ Failed: {failed}")
    print()

def generate_summary():
    """Generate summary of all images"""
    print("=" * 70)
    print("IMAGE SUMMARY")
    print("=" * 70)
    print()

    total_images = 0
    by_variant = {}
    by_set = {}

    for folder in sorted(os.listdir(IMAGE_DIR)):
        folder_path = os.path.join(IMAGE_DIR, folder)

        if not os.path.isdir(folder_path):
            continue

        images = [f for f in os.listdir(folder_path) if f.endswith(('.avif', '.jpg', '.png'))]
        total_images += len(images)
        by_set[folder] = len(images)

        # Count by variant
        for img in images:
            if 'enchanted' in img:
                by_variant['Enchanted'] = by_variant.get('Enchanted', 0) + 1
            elif 'epic' in img:
                by_variant['Epic'] = by_variant.get('Epic', 0) + 1
            elif 'iconic' in img:
                by_variant['Iconic'] = by_variant.get('Iconic', 0) + 1
            elif 'promo' in img:
                by_variant['Promo'] = by_variant.get('Promo', 0) + 1
            else:
                by_variant['Normal'] = by_variant.get('Normal', 0) + 1

    print(f"Total Images: {total_images}")
    print()
    print("By Variant:")
    for variant, count in sorted(by_variant.items()):
        print(f"  • {variant}: {count}")
    print()
    print("By Set:")
    for set_name, count in sorted(by_set.items()):
        print(f"  • {set_name}: {count}")
    print()

if __name__ == "__main__":
    print()
    print("🎴 COMPLETE IMAGE DOWNLOAD & STANDARDIZATION")
    print()

    # Step 1: Download missing images
    download_missing_images()

    # Step 2: Standardize names
    standardize_image_names()

    # Step 3: Convert to JPG (optional but recommended)
    print("⚠️  AVIF->JPG conversion requires Pillow library")
    print("   iOS supports AVIF natively, so this is optional.")
    response = input("   Convert to JPG? (y/n): ").strip().lower()
    if response == 'y':
        convert_avif_to_jpg()

    # Step 4: Summary
    generate_summary()

    print("=" * 70)
    print("✅ COMPLETE!")
    print("=" * 70)
