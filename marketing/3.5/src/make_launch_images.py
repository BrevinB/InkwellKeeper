#!/usr/bin/env python3
"""3.5.0 (storage) launch images.

    python3 marketing/3.5/src/make_launch_images.py

Writes 1080×1350 Instagram feed images and a 1600×900 X image to
marketing/drafts/images/2026-10-13/, plus 1080×1920 reel stills to
marketing/drafts/reels/2026-10-13/stills/ (assembled by make_reel.sh).

Style per the marketing-image-style notes: the in-app navy → plum gradient with
gold sparkles and an ink ribbon; Avenir Next Condensed Heavy uppercase paired
with gold Baskerville italic for the accent words. Screens are real simulator
captures; binder covers are the app's own Blender renders, tinted the way the
app tints them.
"""

import importlib.util
import json
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT_IMAGES = ROOT / "marketing/drafts/images/2026-10-13"
OUT_STILLS = ROOT / "marketing/drafts/reels/2026-10-13/stills"
CAPTURES = Path.home() / "Desktop/InkwellKeeper-Screenshots/3.5/iPhone"
BOOKSHELF = CAPTURES / "iPhone 17 Pro Max - 2026-10-09 at 23.59.22.png"
BINDER_PAGE = CAPTURES / "iPhone 17 Pro Max - 2026-10-09 at 23.59.59.png"
ART = ROOT / "Inkwell Keeper/Assets.xcassets/StorageArt"
METRICS = ROOT / "Inkwell Keeper/Components/Storage/RenderedArtworkMetrics+Generated.swift"

# Brand helpers shared with the in-app event art.
_spec = importlib.util.spec_from_file_location("event_art", ROOT / "screenshots/in-app-event/src/render_event_art.py")
event_art = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(event_art)

HEAVY = ("/System/Library/Fonts/Avenir Next Condensed.ttc", 8)
DEMI = ("/System/Library/Fonts/Avenir Next.ttc", 2)
ITALIC = ("/System/Library/Fonts/Supplemental/Baskerville.ttc", 2)
WHITE = (255, 255, 255)
GOLD = (255, 215, 0)
SOFT = (200, 196, 220)

# StorageCoverColor.highlight, in app order.
COVER_COLORS = {
    "amber": (0.96, 0.70, 0.25), "amethyst": (0.62, 0.40, 0.85), "emerald": (0.25, 0.72, 0.45),
    "ruby": (0.88, 0.28, 0.32), "sapphire": (0.28, 0.55, 0.92), "steel": (0.66, 0.70, 0.76),
    "midnight": (0.22, 0.24, 0.40), "ivory": (0.95, 0.91, 0.82),
}


def font(spec, size):
    return ImageFont.truetype(spec[0], size, index=spec[1])


def text_layer(canvas):
    """Text is drawn on a separate layer, kept on the image itself, so sparkles can be kept off it."""
    if "text_layer" not in canvas.info:
        canvas.info["text_layer"] = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    return canvas.info["text_layer"]


def mark_background(canvas):
    """Remember the bare background, so sparkles can later go only where nothing was placed."""
    canvas.info["bare"] = canvas.copy()
    return canvas


def finish(canvas, seed, count=110, stars=18):
    """Sparkles only on bare background — never on text, screens, covers or cards."""
    layer = text_layer(canvas)
    keep_clear = layer.getchannel("A").point(lambda v: 255 if v > 8 else 0)
    if "bare" in canvas.info:
        changed = ImageChops.difference(canvas.convert("RGB"), canvas.info["bare"].convert("RGB")).convert("L")
        keep_clear = ImageChops.lighter(keep_clear, changed.point(lambda v: 255 if v > 6 else 0))
    keep_clear = keep_clear.filter(ImageFilter.MaxFilter(41))
    spark = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    event_art.sparkles(spark, seed, count, stars, canvas.height)
    spark.putalpha(ImageChops.multiply(spark.getchannel("A"), ImageChops.invert(keep_clear)))
    out = canvas.copy()
    out.alpha_composite(spark)
    out.alpha_composite(layer)
    return out


def text_center(canvas, y, text, spec, size, fill, tracking=0, max_width=None):
    """Centred text; shrinks until it fits `max_width`. Returns the y below it."""
    draw = ImageDraw.Draw(text_layer(canvas))
    while True:
        f = font(spec, size)
        width = draw.textlength(text, font=f) + tracking * (len(text) - 1)
        if not max_width or width <= max_width or size < 20:
            break
        size -= 4
    x = (canvas.width - width) / 2
    if tracking:
        for ch in text:
            draw.text((x, y), ch, font=f, fill=fill)
            x += draw.textlength(ch, font=f) + tracking
    else:
        draw.text((x, y), text, font=f, fill=fill)
    box = draw.textbbox((0, y), text, font=f)
    return box[3]


def background(w, h, ribbon_color, ribbon_y):
    canvas = event_art.gradient(w, h)
    event_art.glow(canvas, (w * .05, h * .25, w * .95, h * .85), (128, 51, 204), .35, 160)
    event_art.ribbon(canvas, event_art.bezier((-60, ribbon_y + 160), (w * .3, ribbon_y - 200), (w * .6, ribbon_y + 260), (w + 60, ribbon_y - 80)), ribbon_color)
    return mark_background(canvas)


def screen(image_path, crop, width, radius=44):
    """A crop of a real capture, as a rounded floating screen with a gold edge and shadow."""
    shot = Image.open(image_path).convert("RGBA").crop(crop)
    height = round(width * shot.height / shot.width)
    shot = shot.resize((width, height), Image.LANCZOS)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    shot.putalpha(mask)
    pad = 60
    tile = Image.new("RGBA", (width + pad * 2, height + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((pad, pad + 24, pad + width, pad + height + 24), radius=radius, fill=(0, 0, 0, 190))
    tile.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    rim = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle((pad - 3, pad - 3, pad + width + 2, pad + height + 2), radius=radius + 3, fill=GOLD + (110,))
    tile.alpha_composite(rim)
    tile.alpha_composite(shot, (pad, pad))
    return tile, pad


def place_center(canvas, tile, center_x, top):
    canvas.alpha_composite(tile, (round(center_x - tile.width / 2), round(top)))


def cover_metrics():
    """coverPlate / coverEmblem rects from the generated Swift metrics."""
    text = METRICS.read_text()
    rects = {}
    for name in ("coverPlate", "coverEmblem"):
        m = re.search(rf"{name} = CGRect\(x: ([\d.]+), y: ([\d.]+), width: ([\d.]+), height: ([\d.]+)\)", text)
        rects[name] = tuple(float(v) for v in m.groups())
    return rects


def binder_cover(color, finish="classic", width=300):
    """The app's rendered binder cover, tinted like TintedRenderLayer, with its gold ornaments."""
    name = f"bindercover_base_{finish}"
    shade = Image.open(ART / f"{name}_shade.imageset/{name}_shade.png").convert("RGBA")
    mask = Image.open(ART / f"{name}_mask.imageset/{name}_mask.png").convert("RGBA").getchannel("A")
    tint = Image.new("RGBA", shade.size, tuple(round(c * 255) for c in color) + (255,))
    multiplied = ImageChops.multiply(shade, tint)
    multiplied.putalpha(shade.getchannel("A"))
    cover = Image.composite(multiplied, shade, mask)
    w, h = cover.size
    for key, file in (("coverPlate", "bindercover_plate"), ("coverEmblem", "bindercover_emblem")):
        x, y, rw, rh = cover_metrics()[key]
        orn = Image.open(ART / f"{file}.imageset/{file}.png").convert("RGBA").resize((round(rw * w), round(rh * h)), Image.LANCZOS)
        cover.alpha_composite(orn, (round(x * w), round(y * h)))
    height = round(width * h / w)
    return cover.resize((width, height), Image.LANCZOS)


def drop_shadowed(img, blur=22, offset=18, alpha=170):
    pad = blur * 3
    tile = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, alpha), (pad, pad + offset, pad + img.width, pad + img.height + offset), img.getchannel("A"))
    tile.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(blur)))
    tile.alpha_composite(img, (pad, pad))
    return tile


def cta(canvas, y, text="Free on iOS"):
    """Gold pill CTA with dark text, per the brand style."""
    draw = ImageDraw.Draw(text_layer(canvas))
    f = font(DEMI, 34)
    w = draw.textlength(text, font=f)
    box = ((canvas.width - w) / 2 - 34, y, (canvas.width + w) / 2 + 34, y + 66)
    draw.rounded_rectangle(box, radius=33, fill=GOLD)
    draw.text(((canvas.width - w) / 2, y + 12), text, font=f, fill=(21, 20, 33))


# ---------------------------------------------------------------------------
# Feed images
# ---------------------------------------------------------------------------


def ig_storage_hero():
    c = background(1080, 1350, event_art.INK["amber"], 640)
    y = text_center(c, 70, "EVERY BINDER.", HEAVY, 120, WHITE, max_width=920)
    y = text_center(c, y + 4, "EVERY BOX.", HEAVY, 120, WHITE, max_width=920)
    text_center(c, y + 10, "finally organized", ITALIC, 64, GOLD)
    tile, _ = screen(BOOKSHELF, (0, 470, 1320, 2470), 720)
    place_center(c, tile, 540, 420)
    return c


def ig_binder_page():
    c = background(1080, 1350, event_art.INK["amethyst"], 560)
    y = text_center(c, 70, "FLIP IT LIKE", HEAVY, 120, WHITE, max_width=920)
    text_center(c, y + 6, "the real thing", ITALIC, 70, GOLD)
    tile, _ = screen(BINDER_PAGE, (50, 580, 1270, 2300), 760, radius=28)
    tile = tile.rotate(-3, resample=Image.BICUBIC, expand=True)
    place_center(c, tile, 540, 300)
    return c


def ig_covers():
    c = background(1080, 1350, event_art.INK["sapphire"], 620)
    y = text_center(c, 70, "PICK YOUR BINDER", HEAVY, 110, WHITE, max_width=960)
    text_center(c, y + 6, "eight colors · leather or stitched", ITALIC, 52, GOLD)
    colors = list(COVER_COLORS.values())
    w = 228
    gap_x, gap_y = 20, 64
    for i, color in enumerate(colors):
        row, col = divmod(i, 4)
        cover = binder_cover(color, "stitched" if (row + col) % 2 else "classic", w)
        tile = drop_shadowed(cover)
        x = 540 + (col - 1.5) * (w + gap_x)
        top = 330 + row * (cover.height + gap_y)
        c.alpha_composite(tile, (round(x - tile.width / 2), round(top - (tile.height - cover.height) / 2 + 8)))
    text_center(c, 1080, "+ Starlight & Holofoil finishes with Pro", ITALIC, 44, SOFT)
    cta(c, 1200)
    return c


def ig_hyperia_day():
    c = event_art.gradient(1080, 1350)
    event_art.glow(c, (60, 380, 1020, 1100), (128, 51, 204), .45, 140)
    event_art.ribbon(c, event_art.bezier((-60, 760), (300, 520), (700, 1000), (1140, 660)), event_art.INK["amber"])
    mark_background(c)
    y = text_center(c, 64, "HYPERIA CITY", HEAVY, 120, WHITE, max_width=960)
    y = text_center(c, y + 2, "IS HERE", HEAVY, 120, WHITE, max_width=960)
    text_center(c, y + 10, "scan your pulls straight into a binder", ITALIC, 50, GOLD, max_width=960)
    card_w = 300
    for i in sorted(range(6), key=lambda i: -abs(i - 2.5)):
        file, ink = event_art.CARDS[i]
        k = i - 2.5
        sprite = event_art.card_sprite(file, ink, card_w).rotate(-k * 9, resample=Image.BICUBIC, expand=True)
        x, ycard = 540 + k * 118, 800 + k * k * 14
        c.alpha_composite(sprite, (round(x - sprite.width / 2), round(ycard - sprite.height / 2)))
    cta(c, 1210, "Free on iOS · in time for Oct 16")
    return c


def x_launch():
    c = background(1600, 900, event_art.INK["amber"], 760)
    d = ImageDraw.Draw(text_layer(c))
    d.text((90, 210), "EVERY BINDER.", font=font(HEAVY, 104), fill=WHITE)
    d.text((90, 320), "EVERY BOX.", font=font(HEAVY, 104), fill=WHITE)
    d.text((94, 446), "finally organized", font=font(ITALIC, 58), fill=GOLD)
    d.text((94, 560), "Storage + Bookshelf · Ink Well Keeper 3.5", font=font(DEMI, 34), fill=SOFT)
    shelf, _ = screen(BOOKSHELF, (0, 470, 1320, 2470), 390, radius=30)
    page, _ = screen(BINDER_PAGE, (50, 580, 1270, 2300), 420, radius=24)
    c.alpha_composite(page.rotate(5, resample=Image.BICUBIC, expand=True), (1090, 130))
    c.alpha_composite(shelf.rotate(-4, resample=Image.BICUBIC, expand=True), (840, 40))
    return c


# ---------------------------------------------------------------------------
# Reel stills (1080×1920)
# ---------------------------------------------------------------------------


def still_title():
    c = background(1080, 1920, event_art.INK["amethyst"], 1100)
    y = text_center(c, 640, "WHERE IS", HEAVY, 150, WHITE, max_width=960)
    y = text_center(c, y + 6, "THAT CARD?", HEAVY, 150, WHITE, max_width=960)
    text_center(c, y + 30, "binder? trove? deck box?", ITALIC, 70, GOLD)
    return c


def still_bookshelf():
    c = background(1080, 1920, event_art.INK["amber"], 760)
    y = text_center(c, 120, "PUT EVERYTHING", HEAVY, 110, WHITE, max_width=960)
    text_center(c, y + 6, "on the shelf", ITALIC, 70, GOLD)
    tile, _ = screen(BOOKSHELF, (0, 330, 1320, 2600), 860)
    place_center(c, tile, 540, 380)
    return c


def still_binder():
    c = background(1080, 1920, event_art.INK["sapphire"], 760)
    y = text_center(c, 120, "FLIP EVERY PAGE", HEAVY, 110, WHITE, max_width=960)
    text_center(c, y + 6, "like the real thing", ITALIC, 70, GOLD)
    tile, _ = screen(BINDER_PAGE, (50, 580, 1270, 2300), 900, radius=30)
    place_center(c, tile, 540, 420)
    return c


def still_covers():
    c = finish(ig_covers(), 303)
    canvas = mark_background(event_art.gradient(1080, 1920))
    canvas.alpha_composite(c, (0, 285))
    return canvas


def still_end():
    c = background(1080, 1920, event_art.INK["amber"], 1250)
    y = text_center(c, 700, "INK WELL KEEPER", HEAVY, 120, WHITE, max_width=960)
    y = text_center(c, y + 10, "your whole collection, organized", ITALIC, 58, GOLD, max_width=960)
    cta(c, y + 70, "Free on iOS")
    return c


def main():
    OUT_IMAGES.mkdir(parents=True, exist_ok=True)
    OUT_STILLS.mkdir(parents=True, exist_ok=True)
    for name, make in (
        ("ig-01-storage-hero.png", ig_storage_hero),
        ("ig-02-binder-page.png", ig_binder_page),
        ("ig-03-pick-your-binder.png", ig_covers),
        ("ig-04-hyperia-city-day.png", ig_hyperia_day),
        ("x-launch-1600x900.png", x_launch),
    ):
        finish(make(), hash(name) % 10_000).convert("RGB").save(OUT_IMAGES / name, optimize=True)
        print("image", name)
    for i, make in enumerate((still_title, still_bookshelf, still_binder, still_covers, still_end), 1):
        name = f"{i:02d}.png"
        finish(make(), 500 + i, count=160, stars=24).convert("RGB").save(OUT_STILLS / name, optimize=True)
        print("still", name)


main()
