#!/usr/bin/env python3
"""
Download all Lorcana card images locally for offline use.
This script reads all set JSON files and downloads the images.
"""

import json
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Tuple

# Configuration
DATA_DIR = "Inkwell Keeper/Data"
IMAGES_DIR = "Inkwell Keeper/Resources/CardImages"
MAX_WORKERS = 10  # Number of concurrent downloads
TIMEOUT = 30  # Seconds

def create_image_directories():
    """Create the directory structure for storing images."""
    Path(IMAGES_DIR).mkdir(parents=True, exist_ok=True)
    print(f"✓ Created image directory: {IMAGES_DIR}")

def load_set_data(json_file: str) -> Dict:
    """Load card data from a set JSON file."""
    with open(json_file, 'r', encoding='utf-8') as f:
        return json.load(f)

def get_all_card_images() -> List[Tuple[str, str, str]]:
    """
    Extract all image URLs from all set JSON files.
    Returns list of tuples: (set_id, image_url, card_unique_id)
    """
    images = []
    data_path = Path(DATA_DIR)

    for json_file in data_path.glob("*.json"):
        if json_file.name == "sets.json":
            continue

        print(f"Reading {json_file.name}...")
        data = load_set_data(json_file)
        set_id = json_file.stem  # Filename without extension

        for card in data.get("cards", []):
            image_url = card.get("Image", "")
            unique_id = card.get("Unique_ID", "")

            if image_url and unique_id:
                images.append((set_id, image_url, unique_id))

    return images

def download_image(args: Tuple[str, str, str, int, int]) -> Tuple[bool, str]:
    """
    Download a single image.
    Args: (set_id, image_url, unique_id, current, total)
    Returns: (success, message)
    """
    set_id, image_url, unique_id, current, total = args

    # Create filename from unique ID (e.g., "TFC-001.png")
    filename = f"{unique_id}.png"

    # Create set subdirectory
    set_dir = Path(IMAGES_DIR) / set_id
    set_dir.mkdir(parents=True, exist_ok=True)

    filepath = set_dir / filename

    # Skip if already exists
    if filepath.exists():
        return (True, f"[{current}/{total}] ⊙ Skipped (exists): {filename}")

    try:
        # Download image
        headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'}
        req = urllib.request.Request(image_url, headers=headers)

        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            image_data = response.read()

        # Save to file
        with open(filepath, 'wb') as f:
            f.write(image_data)

        return (True, f"[{current}/{total}] ✓ Downloaded: {filename}")

    except urllib.error.HTTPError as e:
        return (False, f"[{current}/{total}] ✗ HTTP {e.code}: {filename}")
    except urllib.error.URLError as e:
        return (False, f"[{current}/{total}] ✗ URL Error: {filename} - {e.reason}")
    except Exception as e:
        return (False, f"[{current}/{total}] ✗ Error: {filename} - {str(e)}")

def main():
    """Main execution function."""
    print("=" * 60)
    print("Lorcana Card Image Downloader")
    print("=" * 60)
    print()

    # Create directories
    create_image_directories()
    print()

    # Get all image URLs
    print("Scanning JSON files for image URLs...")
    images = get_all_card_images()
    total_images = len(images)

    print(f"✓ Found {total_images} card images to download")
    print()

    # Confirm download
    print(f"This will download ~{total_images} images.")
    print(f"Estimated size: ~{total_images * 0.15:.0f} MB (assuming ~150KB per image)")
    response = input("Continue? (y/n): ").strip().lower()

    if response != 'y':
        print("Download cancelled.")
        return

    print()
    print("Starting download...")
    print("-" * 60)

    # Download images concurrently
    success_count = 0
    error_count = 0

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        # Submit all download tasks
        futures = []
        for idx, (set_id, url, unique_id) in enumerate(images, 1):
            future = executor.submit(download_image, (set_id, url, unique_id, idx, total_images))
            futures.append(future)

        # Process results as they complete
        for future in as_completed(futures):
            success, message = future.result()
            print(message)

            if success:
                success_count += 1
            else:
                error_count += 1

    # Summary
    print()
    print("-" * 60)
    print("Download Summary:")
    print(f"  Total: {total_images}")
    print(f"  Success: {success_count}")
    print(f"  Errors: {error_count}")
    print()

    if error_count > 0:
        print("⚠ Some images failed to download. You may want to re-run the script.")
    else:
        print("✓ All images downloaded successfully!")

    print()
    print("Next steps:")
    print("1. Images are organized in subdirectories by set")
    print("2. Update JSON files to reference local paths")
    print("3. Update Swift code to load from local assets")

if __name__ == "__main__":
    main()
