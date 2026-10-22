#!/usr/bin/env python3
"""5-slide Instagram/Meta carousel ad: one feature per slide, a real screen in a phone frame.

    /opt/homebrew/bin/python3.14 marketing/ads/src/make_carousel_ad.py

Layout follows the classic app-ad carousel (headline on one side, device on the
other, alternating), but in the app's own look: navy → plum gradient, gold
accents and sparkles kept off text and screens. Screens are real simulator
captures; collection stats on them are demo values (App Store screenshot
convention). Stats, Sets and Bookshelf come from a simulator seeded with
`-seedDemo YES` (DemoCollectionSeeder, DEBUG + simulator only). Writes 1080×1350 PNGs to marketing/drafts/images/2026-10-20/ad-carousel/.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SRC_35 = ROOT / "marketing/3.5/src"

# Brand helpers (gradient, glow, ribbon, sparkle finish) from the 3.5 launch script.
_source = (SRC_35 / "make_launch_images.py").read_text().rsplit("\nmain()", 1)[0]
brand = {"__file__": str(SRC_35 / "make_launch_images.py"), "__name__": "brand"}
exec(compile(_source, "make_launch_images.py", "exec"), brand)
event_art, font, text_layer = brand["event_art"], brand["font"], brand["text_layer"]
mark_background, cta = brand["mark_background"], brand["cta"]
WHITE, GOLD, SOFT = brand["WHITE"], brand["GOLD"], brand["SOFT"]

HEADLINE = ("/System/Library/Fonts/Avenir Next.ttc", 8)  # Heavy, mixed case
BODY = ("/System/Library/Fonts/Avenir Next.ttc", 5)      # Medium
OUT = ROOT / "marketing/drafts/images/2026-10-20/ad-carousel"
CAPTURES = Path.home() / "Desktop/InkwellKeeper-Screenshots"
ICON = ROOT.parent / "inkwellkeeper-site/assets/appstore/icon-512.png"

W, H = 1080, 1350


def finish(canvas, seed, count=110, stars=18):
    """Brand sparkle finish with a doubled clear zone: big headlines caught star arms at the default."""
    layer = text_layer(canvas)
    keep_clear = layer.getchannel("A").point(lambda v: 255 if v > 8 else 0)
    changed = ImageChops.difference(canvas.convert("RGB"), canvas.info["bare"].convert("RGB")).convert("L")
    keep_clear = ImageChops.lighter(keep_clear, changed.point(lambda v: 255 if v > 6 else 0))
    keep_clear = keep_clear.filter(ImageFilter.MaxFilter(41)).filter(ImageFilter.MaxFilter(41))
    spark = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    event_art.sparkles(spark, seed, count, stars, canvas.height)
    spark.putalpha(ImageChops.multiply(spark.getchannel("A"), ImageChops.invert(keep_clear)))
    out = canvas.copy()
    out.alpha_composite(spark)
    out.alpha_composite(layer)
    return out


def capture(name):
    return CAPTURES / name


SLIDES = [
    {   # Multi-scan is the most-used feature, so it leads.
        "screen": capture("3.0/iPhone/scan-still.png"), "phone": "right", "ink": "amber",
        "lines": [("Scan your", WHITE), ("pulls", WHITE), ("all at once.", GOLD)],
        "body": ["Point your camera at", "the stack. Review them", "together, done."],
    },
    {
        "screen": capture("ads-2026-10/stats.png"),
        "phone": "left", "ink": "emerald",
        "lines": [("Your collection", WHITE), ("adds up to", WHITE)],
        "big": "$7,217.96",
        "body": ["3,819 cards.", "Prices updated daily."],
    },
    {
        "screen": capture("ads-2026-10/sets.png"),
        "phone": "right", "ink": "sapphire",
        "lines": [("See exactly", WHITE), ("what you're", WHITE), ("missing.", GOLD)],
        "body": ["Every set fills in", "as you scan."],
    },
    {
        "screen": capture("ads-2026-10/bookshelf.png"),
        "phone": "left", "ink": "ruby",
        "lines": [("Know which", WHITE), ("binder it's in.", GOLD)],
        "body": ["Binders, boxes and", "deck boxes, all on", "one shelf."],
    },
    {
        "screen": capture("ads-2026-10/import.png"),
        "phone": "right", "ink": "amethyst", "end": True,
        "lines": [("Switching", WHITE), ("apps?", WHITE), ("Bring it all.", GOLD)],
        "body": ["Import from the official", "Lorcana app, Dreamborn", "or Collectr in seconds."],
    },
]


def phone(screen_path, height):
    """A capture inside a dark rounded bezel with a Dynamic Island, gold rim, shadow and halo room."""
    shot = Image.open(screen_path).convert("RGBA")
    sw = round(height * shot.width / shot.height)
    shot = shot.resize((sw, height), Image.LANCZOS)
    bezel, radius = 16, round(sw * .16)
    pw, ph = sw + bezel * 2, height + bezel * 2
    body = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, pw - 1, ph - 1), radius=radius + bezel, fill=GOLD + (150,))
    d.rounded_rectangle((3, 3, pw - 4, ph - 4), radius=radius + bezel - 3, fill=(12, 12, 18, 255))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, height - 1), radius=radius, fill=255)
    body.paste(shot, (bezel, bezel), mask)
    island_w, island_h = round(sw * .29), round(sw * .085)
    ix, iy = (pw - island_w) / 2, bezel + round(sw * .028)
    d.rounded_rectangle((ix, iy, ix + island_w, iy + island_h), radius=island_h / 2, fill=(0, 0, 0, 255))

    pad = 90
    tile = Image.new("RGBA", (pw + pad * 2, ph + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((pad, pad + 30, pad + pw, pad + ph + 30), radius=radius, fill=(0, 0, 0, 200))
    tile.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(36)))
    tile.alpha_composite(body, (pad, pad))
    return tile


def text_left(canvas, x, y, text, spec, size, fill, max_width):
    """Left-aligned text that shrinks to fit. Returns the y below it."""
    d = ImageDraw.Draw(text_layer(canvas))
    while d.textlength(text, font=font(spec, size)) > max_width and size > 20:
        size -= 2
    f = font(spec, size)
    d.text((x, y), text, font=f, fill=fill)
    return d.textbbox((x, y), text, font=f)[3]


def progress(canvas, index):
    """Carousel position dots, so each slide reads as part of a set."""
    d = ImageDraw.Draw(text_layer(canvas))
    x = W / 2 - 70
    for i in range(len(SLIDES)):
        w = 44 if i == index else 12
        d.rounded_rectangle((x, H - 52, x + w, H - 40), radius=6, fill=GOLD if i == index else SOFT + (110,))
        x += w + 12


def slide(index):
    spec = SLIDES[index]
    c = event_art.gradient(W, H)
    left_phone = spec["phone"] == "left"
    phone_cx = 290 if left_phone else 790
    event_art.glow(c, (phone_cx - 340, 160, phone_cx + 340, 1240), event_art.INK[spec["ink"]], .32, 140)
    event_art.ribbon(c, event_art.bezier((-60, 1240), (W * .3, 1000), (W * .65, 1380), (W + 60, 1120)), event_art.INK[spec["ink"]])
    mark_background(c)

    tile = phone(spec["screen"], 1000)
    c.alpha_composite(tile, (round(phone_cx - tile.width / 2), round(H / 2 - tile.height / 2) - 20))

    text_x = 580 if left_phone else 64
    text_w = 440 if left_phone else 440
    y = 330 if spec.get("big") else 400
    for line, color in spec["lines"]:
        y = text_left(c, text_x, y, line, HEADLINE, 84, color, text_w) + 2
    if spec.get("big"):
        y = text_left(c, text_x, y + 10, spec["big"], HEADLINE, 116, GOLD, text_w) + 4
    y += 50
    for line in spec["body"]:
        y = text_left(c, text_x, y, line, BODY, 40, SOFT, text_w) + 8

    if spec.get("end"):
        icon = Image.open(ICON).convert("RGBA").resize((96, 96), Image.LANCZOS)
        m = Image.new("L", icon.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, 95, 95), radius=22, fill=255)
        icon.putalpha(m)
        iy = y + 70
        text_layer(c).paste(icon, (text_x, iy), icon)
        text_left(c, text_x + 116, iy + 4, "Ink Well", HEADLINE, 40, WHITE, 320)
        text_left(c, text_x + 116, iy + 48, "Keeper", HEADLINE, 40, WHITE, 320)
        pill = ImageDraw.Draw(text_layer(c))
        f = font(brand["DEMI"], 34)
        label = "Free on iOS"
        tw = pill.textlength(label, font=f)
        py = iy + 136
        pill.rounded_rectangle((text_x, py, text_x + tw + 68, py + 66), radius=33, fill=GOLD)
        pill.text((text_x + 34, py + 12), label, font=f, fill=(21, 20, 33))
    progress(c, index)
    return c


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(len(SLIDES)):
        name = f"ad-{i + 1}.png"
        finish(slide(i), 3100 + i).convert("RGB").save(OUT / name, optimize=True)
        print("slide", name)


main()
