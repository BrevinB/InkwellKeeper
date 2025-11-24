#!/usr/bin/env python3
"""
Rename enchanted card images to use normal card collector numbers
"""

import json
import os
import shutil

IMAGE_DIR = "Inkwell Keeper/Resources/CardImages"

def rename_enchanted_images():
    """Rename enchanted images based on mapping"""
    print("🖼️  Renaming Enchanted Card Images")
    print("=" * 80)

    # Load mapping
    with open("enchanted_to_normal_mapping.json", "r") as f:
        mapping = json.load(f)

    total_renamed = 0
    total_missing = 0

    for set_code, set_data in mapping.items():
        folder_name = set_data["folder"]
        cards = set_data["cards"]

        print(f"\n📚 Processing {folder_name} ({set_code})")
        print("-" * 80)

        for card in cards:
            enchanted_id = card["enchanted_id"]
            normal_id = card["normal_id"]
            card_name = card["name"]

            # Try different extensions
            for ext in ["jpg", "png", "avif"]:
                old_path = os.path.join(IMAGE_DIR, folder_name, f"{enchanted_id}-enchanted.{ext}")
                new_path = os.path.join(IMAGE_DIR, folder_name, f"{normal_id}-enchanted.{ext}")

                if os.path.exists(old_path):
                    # Check if target already exists
                    if os.path.exists(new_path):
                        print(f"  ⚠️  {normal_id}-enchanted.{ext} already exists, skipping {enchanted_id}")
                    else:
                        shutil.move(old_path, new_path)
                        total_renamed += 1
                        print(f"  ✅ {enchanted_id}-enchanted.{ext} → {normal_id}-enchanted.{ext}")
                    break
            else:
                # No file found with any extension
                total_missing += 1
                print(f"  ❌ Missing: {enchanted_id}-enchanted (tried jpg/png/avif)")

    print("\n" + "=" * 80)
    print(f"✅ Renamed {total_renamed} enchanted images")
    if total_missing > 0:
        print(f"⚠️  {total_missing} images were missing")
    print("=" * 80)

if __name__ == "__main__":
    rename_enchanted_images()
