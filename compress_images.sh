#!/bin/bash
# Compress card images using macOS's built-in sips command
# Reduces file sizes while maintaining good visual quality

CARD_IMAGES_DIR="Inkwell Keeper/Resources/CardImages"
MAX_WIDTH=800
JPEG_QUALITY=85
DRY_RUN=false  # Set to false to actually compress

echo "🖼️  Card Image Compression Tool"
echo "📁 Directory: $CARD_IMAGES_DIR"
echo "📏 Max width: ${MAX_WIDTH}px"
echo "🎨 JPEG quality: ${JPEG_QUALITY}%"
echo "🔍 Dry run: $DRY_RUN"
echo "------------------------------------------------------------"

# Find all PNG and JPG files
image_count=0
total_old_size=0
total_new_size=0

# Count images first
total_images=$(find "$CARD_IMAGES_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) | wc -l | tr -d ' ')
echo "Found $total_images images to process"
echo

if [ "$DRY_RUN" = true ]; then
    echo "⚠️  DRY RUN MODE - No files will be modified"
    echo
fi

# Process each image
find "$CARD_IMAGES_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) | while read -r image_path; do
    ((image_count++))

    # Get original size
    old_size=$(stat -f%z "$image_path")
    ((total_old_size += old_size))

    # Get image width
    width=$(sips -g pixelWidth "$image_path" 2>/dev/null | grep pixelWidth | awk '{print $2}')

    if [ "$DRY_RUN" = true ]; then
        if [ $((image_count % 100)) -eq 0 ]; then
            echo "Checked $image_count/$total_images images..."
        fi
    else
        # Create new filename with .jpg extension
        dir=$(dirname "$image_path")
        filename=$(basename "$image_path")
        base="${filename%.*}"
        new_path="$dir/${base}.jpg"

        # Compress and resize
        if [ "$width" -gt "$MAX_WIDTH" ]; then
            sips -s format jpeg -s formatOptions "$JPEG_QUALITY" --resampleWidth "$MAX_WIDTH" "$image_path" --out "$new_path" >/dev/null 2>&1
        else
            sips -s format jpeg -s formatOptions "$JPEG_QUALITY" "$image_path" --out "$new_path" >/dev/null 2>&1
        fi

        # If conversion succeeded and we created a different file, delete original
        if [ -f "$new_path" ] && [ "$new_path" != "$image_path" ]; then
            rm "$image_path"
        fi

        # Get new size
        new_size=$(stat -f%z "$new_path")
        ((total_new_size += new_size))

        if [ $((image_count % 100)) -eq 0 ]; then
            reduction=$(echo "scale=1; (1 - $total_new_size / $total_old_size) * 100" | bc)
            echo "Processed $image_count/$total_images images... (${reduction}% reduction so far)"
        fi
    fi
done

echo
echo "============================================================"
echo "✅ Complete!"
echo "============================================================"

if [ "$DRY_RUN" = true ]; then
    echo "Found $total_images images that would be compressed"
    echo
    echo "Expected results:"
    echo "  • Each PNG (~1.5MB) → JPEG (~300KB)"
    echo "  • Total: ~2.9GB → ~550MB"
    echo "  • Reduction: ~80%"
    echo "  • Space saved: ~2.3GB"
    echo
    echo "To actually compress, edit compress_images.sh and set DRY_RUN=false"
else
    old_size_gb=$(echo "scale=2; $total_old_size / 1073741824" | bc)
    new_size_gb=$(echo "scale=2; $total_new_size / 1073741824" | bc)
    saved_gb=$(echo "scale=2; ($total_old_size - $total_new_size) / 1073741824" | bc)
    reduction=$(echo "scale=1; (1 - $total_new_size / $total_old_size) * 100" | bc)

    echo "📊 Images processed: $image_count"
    echo "💾 Original size: ${old_size_gb} GB"
    echo "💾 New size: ${new_size_gb} GB"
    echo "📉 Total reduction: ${reduction}%"
    echo "💰 Space saved: ${saved_gb} GB"
fi
