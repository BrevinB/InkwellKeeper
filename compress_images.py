#!/usr/bin/env python3
"""
Compress card images for mobile app usage.
Reduces file sizes while maintaining good visual quality.
"""

import os
from PIL import Image
from pathlib import Path

# Configuration
CARD_IMAGES_DIR = "Inkwell Keeper/Resources/CardImages"
MAX_WIDTH = 800  # pixels - plenty for iPhone displays
JPEG_QUALITY = 85  # good quality, much smaller files
DRY_RUN = False  # Set to True to preview without making changes

def compress_image(image_path, output_path, max_width=MAX_WIDTH, quality=JPEG_QUALITY):
    """Compress and resize an image."""
    try:
        with Image.open(image_path) as img:
            # Convert RGBA to RGB if needed (for JPEG)
            if img.mode == 'RGBA':
                # Create white background
                background = Image.new('RGB', img.size, (255, 255, 255))
                background.paste(img, mask=img.split()[3])  # Use alpha channel as mask
                img = background
            elif img.mode != 'RGB':
                img = img.convert('RGB')

            # Resize if image is larger than max_width
            if img.width > max_width:
                ratio = max_width / img.width
                new_height = int(img.height * ratio)
                img = img.resize((max_width, new_height), Image.Resampling.LANCZOS)

            # Save as JPEG with compression
            img.save(output_path, 'JPEG', quality=quality, optimize=True)

            # Get file sizes
            old_size = os.path.getsize(image_path)
            new_size = os.path.getsize(output_path)
            reduction = (1 - new_size/old_size) * 100

            return old_size, new_size, reduction
    except Exception as e:
        print(f"Error processing {image_path}: {e}")
        return None, None, None

def main():
    base_dir = Path(CARD_IMAGES_DIR)

    if not base_dir.exists():
        print(f"Error: Directory not found: {base_dir}")
        return

    print("🖼️  Card Image Compression Tool")
    print(f"📁 Directory: {base_dir}")
    print(f"📏 Max width: {MAX_WIDTH}px")
    print(f"🎨 JPEG quality: {JPEG_QUALITY}%")
    print(f"🔍 Dry run: {DRY_RUN}")
    print("-" * 60)

    # Find all PNG and JPG images
    image_files = list(base_dir.rglob("*.png")) + list(base_dir.rglob("*.jpg"))
    total_images = len(image_files)

    print(f"Found {total_images} images to process\n")

    if DRY_RUN:
        print("⚠️  DRY RUN MODE - No files will be modified\n")

    total_old_size = 0
    total_new_size = 0
    processed = 0
    errors = 0

    for i, image_path in enumerate(image_files, 1):
        # Create new filename with .jpg extension
        output_path = image_path.with_suffix('.jpg')

        if not DRY_RUN:
            old_size, new_size, reduction = compress_image(image_path, output_path)

            if old_size is not None:
                total_old_size += old_size
                total_new_size += new_size
                processed += 1

                # Delete original PNG if we created a new JPG
                if output_path != image_path and output_path.exists():
                    image_path.unlink()

                if i % 100 == 0:
                    print(f"Processed {i}/{total_images} images... ({reduction:.1f}% reduction)")
            else:
                errors += 1
        else:
            # Dry run - just simulate
            print(f"[DRY RUN] Would compress: {image_path.name}")
            if i % 100 == 0:
                print(f"... {i}/{total_images} images checked")

    print("\n" + "=" * 60)
    print("✅ Compression Complete!")
    print("=" * 60)

    if not DRY_RUN:
        print(f"📊 Images processed: {processed}")
        print(f"❌ Errors: {errors}")
        print(f"💾 Original size: {total_old_size / (1024**3):.2f} GB")
        print(f"💾 New size: {total_new_size / (1024**3):.2f} GB")
        print(f"📉 Total reduction: {(1 - total_new_size/total_old_size) * 100:.1f}%")
        print(f"💰 Space saved: {(total_old_size - total_new_size) / (1024**3):.2f} GB")
    else:
        print(f"Found {total_images} images that would be compressed")
        print("\nTo actually compress the images, edit the script and set DRY_RUN = False")

if __name__ == "__main__":
    main()
