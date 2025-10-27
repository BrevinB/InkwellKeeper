#!/usr/bin/env python3
"""
Download Reign of Jafar card images specifically.
"""

import json
import urllib.request
import urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configuration
DATA_FILE = "Inkwell Keeper/Data/reign_of_jafar.json"
OUTPUT_DIR = "Inkwell Keeper/Resources/CardImages/reign_of_jafar"
MAX_WORKERS = 5  # Lower for official API
TIMEOUT = 30

def download_image(args):
    """Download a single image."""
    image_url, unique_id, current, total = args

    filename = f"{unique_id}.jpg"  # Note: .jpg instead of .png for Ravensburger API
    filepath = Path(OUTPUT_DIR) / filename

    # Skip if exists
    if filepath.exists():
        return (True, f"[{current}/{total}] ⊙ Skipped: {filename}")

    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8'
        }
        req = urllib.request.Request(image_url, headers=headers)

        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            image_data = response.read()

        with open(filepath, 'wb') as f:
            f.write(image_data)

        return (True, f"[{current}/{total}] ✓ Downloaded: {filename}")

    except Exception as e:
        return (False, f"[{current}/{total}] ✗ Error: {filename} - {str(e)}")

def main():
    print("Downloading Reign of Jafar images...")
    print("=" * 60)

    # Create output directory
    Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

    # Load JSON
    with open(DATA_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Extract image URLs
    images = []
    for card in data.get("cards", []):
        image_url = card.get("Image", "")
        unique_id = card.get("Unique_ID", "")
        if image_url and unique_id:
            images.append((image_url, unique_id))

    total = len(images)
    print(f"Found {total} images to download\n")

    # Download
    success = 0
    errors = 0

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = []
        for idx, (url, uid) in enumerate(images, 1):
            future = executor.submit(download_image, (url, uid, idx, total))
            futures.append(future)

        for future in as_completed(futures):
            ok, msg = future.result()
            print(msg)
            if ok:
                success += 1
            else:
                errors += 1

    print("\n" + "=" * 60)
    print(f"Success: {success}/{total}")
    print(f"Errors: {errors}")

    if errors == 0:
        print("✓ All Reign of Jafar images downloaded!")
    else:
        print("⚠ Some images failed. Check errors above.")

if __name__ == "__main__":
    main()
