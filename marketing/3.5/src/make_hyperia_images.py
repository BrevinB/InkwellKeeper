#!/usr/bin/env python3
"""Hyperia City (Set 14) set-day images, story frames and reel stills.

    python3 marketing/3.5/src/make_hyperia_images.py [images|reels|<file name>|<reel> ...]

Card data and art come straight from the app bundle (hyperia_city.json and
Resources/CardImages/hyperia_city/), so it needs the 3.5.1 card sync that
added the Epics and Enchanteds.

Writes 1080×1350 feed images, 1080×1920 story frames and a 1600×900 X image to
marketing/drafts/images/2026-10-16/, plus 1080×1920 reel stills to
marketing/drafts/reels/2026-10-16/stills-<reel>/ (assembled by make_hyperia_reel.sh).

Reuses the brand helpers from make_launch_images.py (gradient, ink ribbon,
sparkles kept off text and cards, Avenir Condensed + gold Baskerville italic).
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT_IMAGES = ROOT / "marketing/drafts/images/2026-10-16"
OUT_REELS = ROOT / "marketing/drafts/reels/2026-10-16"
CARD_IMAGES = ROOT / "Inkwell Keeper/Resources/CardImages/hyperia_city"

# Load the 3.5 launch helpers without running that script's main().
_source = (HERE / "make_launch_images.py").read_text().rsplit("\nmain()", 1)[0]
brand = {"__file__": str(HERE / "make_launch_images.py"), "__name__": "brand"}
exec(compile(_source, "make_launch_images.py", "exec"), brand)
event_art = brand["event_art"]
text_center, cta, background = brand["text_center"], brand["cta"], brand["background"]
mark_background = brand["mark_background"]
HEAVY, DEMI, ITALIC = brand["HEAVY"], brand["DEMI"], brand["ITALIC"]
WHITE, GOLD, SOFT = brand["WHITE"], brand["GOLD"], brand["SOFT"]



def load_cards():
    """{collector number: card} from the bundled set file, with the bundled image path."""
    doc = json.loads((ROOT / "Inkwell Keeper/Data/hyperia_city.json").read_text())
    cards = {}
    for card in doc["cards"]:
        name, _, version = card["name"].partition(" - ")
        suffix = "" if card["variant"] == "Normal" else "-" + card["variant"].lower()
        cards[card["cardNumber"]] = {
            "name": name, "version": version or None, "rarity": card["rarity"],
            "ink": card["inkColor"], "image": CARD_IMAGES / f"{card['uniqueId']}{suffix}.avif",
        }
    return cards


CARDS = load_cards()


def by_rarity(rarity):
    return [n for n in sorted(CARDS) if CARDS[n]["rarity"] == rarity]


ENCHANTED, ICONIC, EPIC, LEGENDARY = (by_rarity(r) for r in ("Enchanted", "Iconic", "Epic", "Legendary"))

# Main-set counts by rarity (Lorcast, Oct 14 2026), plus the 38 numbered specials.
RARITY_ROWS = [
    ("Common", 72), ("Uncommon", 54), ("Rare", 48), ("Super Rare", 18),
    ("Legendary", 12), ("Epic", 18), ("Enchanted", 18), ("Iconic", 2),
]


def finish(canvas, seed, count=110, stars=18):
    """make_launch_images.finish with a wider clear zone: these headlines are bigger, so stars sat on their edges."""
    layer = brand["text_layer"](canvas)
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


def ink(n):
    return event_art.INK[CARDS[n]["ink"].split("-")[0].lower()]


def sprite(n, width, rotate=0):
    tile = event_art.card_sprite(CARDS[n]["image"], ink(n), width)
    return tile.rotate(rotate, resample=Image.BICUBIC, expand=True) if rotate else tile


def place(canvas, tile, cx, cy):
    """alpha_composite centred at (cx, cy), cropping whatever falls off the canvas."""
    x, y = round(cx - tile.width / 2), round(cy - tile.height / 2)
    sx, sy = max(0, -x), max(0, -y)
    tile = tile.crop((sx, sy, min(tile.width, canvas.width - x), min(tile.height, canvas.height - y)))
    canvas.alpha_composite(tile, (x + sx, y + sy))


def title(n):
    card = CARDS[n]
    return card["name"] + (f" – {card['version']}" if card["version"] else "")


# ---------------------------------------------------------------------------
# Feed images
# ---------------------------------------------------------------------------


def ig_enchanted_cover():
    """Carousel slide 1: a fan of Enchanteds under a type-led headline."""
    c = event_art.gradient(1080, 1350)
    event_art.glow(c, (40, 420, 1040, 1180), (128, 51, 204), .5, 150)
    event_art.ribbon(c, event_art.bezier((-60, 820), (300, 560), (720, 1060), (1140, 700)), event_art.INK["amethyst"])
    mark_background(c)
    y = text_center(c, 60, "18 ENCHANTEDS", HEAVY, 132, WHITE, max_width=960)
    y = text_center(c, y + 4, "+ 2 ICONICS", HEAVY, 84, GOLD, max_width=960)
    text_center(c, y + 14, "which one are you chasing?", ITALIC, 56, GOLD, max_width=960)
    fan = [230, 226, 236, 232, 239]  # Belle, Rapunzel, Ariel, Héctor, Tiana
    for i in sorted(range(len(fan)), key=lambda i: -abs(i - 2)):
        k = i - 2
        place(c, sprite(fan[i], 330, rotate=-k * 10), 540 + k * 160, 860 + k * k * 22)
    text_center(c, 1262, "swipe for all 18 + the Iconics", DEMI, 34, SOFT)
    return c


def ig_enchanted_grid(cards, label):
    """Carousel slides 2–4: six Enchanteds, two inks, with names."""
    c = event_art.gradient(1080, 1350)
    event_art.glow(c, (40, 200, 1040, 1250), (128, 51, 204), .35, 150)
    mark_background(c)
    text_center(c, 48, label, HEAVY, 72, WHITE, tracking=4, max_width=980)
    for i, n in enumerate(cards):
        col, row = i % 3, i // 3
        cx, cy = 190 + col * 350, 420 + row * 560
        place(c, sprite(n, 290), cx, cy)
        name = CARDS[n]["name"]
        draw_y = cy + 220
        # Names under each card, small and centred in the column.
        f = brand["font"](DEMI, 30)
        layer = brand["text_layer"](c)
        d = ImageDraw.Draw(layer)
        w = d.textlength(name, font=f)
        if w > 330:
            f = brand["font"](DEMI, 24)
            w = d.textlength(name, font=f)
        d.text((cx - w / 2, draw_y), name, font=f, fill=GOLD)
    return c


def ig_iconics():
    c = event_art.gradient(1080, 1350)
    event_art.glow(c, (40, 300, 1040, 1200), (255, 190, 60), .28, 160)
    event_art.ribbon(c, event_art.bezier((-60, 900), (300, 640), (700, 1140), (1140, 780)), event_art.INK["sapphire"])
    mark_background(c)
    y = text_center(c, 60, "THE ICONICS", HEAVY, 132, WHITE, max_width=960)
    text_center(c, y + 10, "the rarest pulls in the set", ITALIC, 56, GOLD, max_width=960)
    a, b = ICONIC
    place(c, sprite(a, 400, rotate=6), 330, 820)
    place(c, sprite(b, 400, rotate=-6), 750, 820)
    cta(c, 1240, "Scan your pulls · Free on iOS")
    return c


def ig_by_the_numbers():
    """Number-led: the set's size, then the rarity split as gold bars."""
    c = background(1080, 1350, event_art.INK["emerald"], 1180)
    y = text_center(c, 40, "242", HEAVY, 340, GOLD, max_width=900)
    y = text_center(c, y - 6, "CARDS IN HYPERIA CITY", HEAVY, 68, WHITE, tracking=3, max_width=960)
    text_center(c, y + 8, "204 in the main set, 38 specials", ITALIC, 48, SOFT, max_width=960)
    layer = brand["text_layer"](c)
    d = ImageDraw.Draw(layer)
    f_label, f_num = brand["font"](DEMI, 38), brand["font"](HEAVY, 46)
    top, step, bar_x, bar_max = 600, 72, 380, 560
    for i, (rarity, count) in enumerate(RARITY_ROWS):
        ry = top + i * step
        d.text((120, ry), rarity, font=f_label, fill=WHITE)
        w = max(10, bar_max * count / 72)
        special = i >= 5
        d.rounded_rectangle((bar_x, ry + 8, bar_x + w, ry + 44), radius=18,
                            fill=GOLD if special else (200, 196, 220, 170))
        d.text((bar_x + w + 18, ry - 2), str(count), font=f_num, fill=GOLD if special else WHITE)
    cta(c, 1224, "Track your collection · Free on iOS")
    return c


def x_set_day():
    c = background(1600, 900, event_art.INK["amber"], 760)
    y = text_center(c, 70, "HYPERIA CITY IS OUT", HEAVY, 116, WHITE, max_width=1440)
    text_center(c, y + 8, "scan your pulls · track the chase", ITALIC, 56, GOLD, max_width=1440)
    fan = [224, 229, 241, 237, 233]
    for i in sorted(range(len(fan)), key=lambda i: -abs(i - 2)):
        k = i - 2
        place(c, sprite(fan[i], 250, rotate=-k * 8), 800 + k * 230, 620 + k * k * 16)
    return c


def ig_legendaries():
    """All 12 Legendaries in a 4×3 grid."""
    c = event_art.gradient(1080, 1350)
    event_art.glow(c, (40, 200, 1040, 1250), (128, 51, 204), .35, 150)
    mark_background(c)
    y = text_center(c, 44, "THE 12 LEGENDARIES", HEAVY, 92, WHITE, max_width=980)
    text_center(c, y + 2, "how many have you pulled?", ITALIC, 48, GOLD, max_width=960)
    for i, n in enumerate(LEGENDARY):
        col, row = i % 4, i // 4
        place(c, sprite(n, 214), 150 + col * 260, 410 + row * 330)
    cta(c, 1250, "Track your pulls · Free on iOS")
    return c


def ig_binder_math():
    """Number-led: how many binder pages the set needs."""
    c = background(1080, 1350, event_art.INK["sapphire"], 1160)
    y = text_center(c, 60, "27", HEAVY, 400, GOLD, max_width=900)
    y = text_center(c, y - 10, "BINDER PAGES", HEAVY, 96, WHITE, tracking=3, max_width=960)
    y = text_center(c, y + 6, "for a full Hyperia City master set", ITALIC, 50, GOLD, max_width=960)
    layer = brand["text_layer"](c)
    d = ImageDraw.Draw(layer)
    f_label, f_num = brand["font"](DEMI, 40), brand["font"](HEAVY, 52)
    rows = [("Main set · 204 cards", "23 pages"), ("Master set · 242 cards", "27 pages"),
            ("Double-sided sheets", "14 sheets")]
    top = y + 90
    for i, (label, value) in enumerate(rows):
        ry = top + i * 96
        d.rounded_rectangle((110, ry - 14, 970, ry + 66), radius=24, fill=(255, 255, 255, 22))
        d.text((146, ry + 2), label, font=f_label, fill=WHITE)
        w = d.textlength(value, font=f_num)
        d.text((934 - w, ry - 4), value, font=f_num, fill=GOLD)
    text_center(c, top + 300, "9-pocket pages, one card per pocket", DEMI, 32, SOFT, max_width=960)
    cta(c, 1240, "Plan your binder · Free on iOS")
    return c


def story(lines, sub, tone):
    """1080×1920 story frame: headline in the top half, the bottom half left clear for a sticker."""
    c = background(1080, 1920, event_art.INK[tone], 1650)
    y = 330
    for line, color in lines:
        y = text_center(c, y, line, HEAVY, 150, color, max_width=960) + 6
    text_center(c, y + 24, sub, ITALIC, 62, GOLD, max_width=960)
    text_center(c, 1780, "INK WELL KEEPER", HEAVY, 44, SOFT, tracking=6, max_width=960)
    return c


# ---------------------------------------------------------------------------
# Reel stills (1080×1920): title → each card → end card
# ---------------------------------------------------------------------------


def still_title(lines, sub, tone):
    c = background(1080, 1920, event_art.INK[tone], 1300)
    y = 620
    for line, color in lines:
        y = text_center(c, y, line, HEAVY, 150, color, max_width=960) + 4
    text_center(c, y + 26, sub, ITALIC, 64, GOLD, max_width=960)
    return c


def still_card(n, index, total, label):
    tone = CARDS[n]["ink"].split("-")[0].lower()
    c = event_art.gradient(1080, 1920)
    event_art.glow(c, (60, 360, 1020, 1560), ink(n), .35, 170)
    event_art.ribbon(c, event_art.bezier((-60, 1500), (300, 1260), (720, 1740), (1140, 1380)), event_art.INK[tone])
    mark_background(c)
    text_center(c, 150, f"{label} {index} / {total}", HEAVY, 54, SOFT, tracking=6, max_width=960)
    place(c, sprite(n, 720), 540, 900)
    y = text_center(c, 1480, CARDS[n]["name"].upper(), HEAVY, 92, WHITE, max_width=960)
    if CARDS[n]["version"]:
        text_center(c, y + 8, CARDS[n]["version"], ITALIC, 58, GOLD, max_width=960)
    return c


def still_end(headline="PULLED ONE?"):
    c = background(1080, 1920, event_art.INK["amber"], 1250)
    y = text_center(c, 640, headline, HEAVY, 140, WHITE, max_width=960)
    y = text_center(c, y + 10, "scan it, track it, show it off", ITALIC, 60, GOLD, max_width=960)
    y = text_center(c, y + 60, "INK WELL KEEPER", HEAVY, 80, WHITE, max_width=960)
    cta(c, y + 50, "Free on iOS")
    return c


def card_stills(cards, label):
    return [lambda n=n, i=i: still_card(n, i, len(cards), label) for i, n in enumerate(cards, 1)]


REELS = {
    "enchanted": lambda: [lambda: still_title([("EVERY", WHITE), ("HYPERIA CITY", WHITE), ("ENCHANTED", GOLD)],
                                              "which one did you pull?", "amethyst")]
    + card_stills(ENCHANTED, "ENCHANTED") + card_stills(ICONIC, "ICONIC") + [still_end],
    "legendary": lambda: [lambda: still_title([("ALL 12", GOLD), ("HYPERIA CITY", WHITE), ("LEGENDARIES", WHITE)],
                                              "rank them in the comments", "ruby")]
    + card_stills(LEGENDARY, "LEGENDARY") + [lambda: still_end("WHICH ONE'S #1?")],
    "epic": lambda: [lambda: still_title([("THE 18", WHITE), ("EPICS", GOLD), ("OF HYPERIA CITY", WHITE)],
                                         "every single one, which is your favourite?", "emerald")]
    + card_stills(EPIC, "EPIC") + [still_end],
}


def main():
    OUT_IMAGES.mkdir(parents=True, exist_ok=True)
    images = [
        ("ig-hyc-01-enchanted-cover.png", ig_enchanted_cover),
        ("ig-hyc-02-enchanted-amber-amethyst.png", lambda: ig_enchanted_grid(ENCHANTED[0:6], "AMBER  ·  AMETHYST")),
        ("ig-hyc-03-enchanted-emerald-ruby.png", lambda: ig_enchanted_grid(ENCHANTED[6:12], "EMERALD  ·  RUBY")),
        ("ig-hyc-04-enchanted-sapphire-steel.png", lambda: ig_enchanted_grid(ENCHANTED[12:18], "SAPPHIRE  ·  STEEL")),
        ("ig-hyc-05-iconics.png", ig_iconics),
        ("ig-hyc-06-by-the-numbers.png", ig_by_the_numbers),
        ("ig-hyc-07-legendaries.png", ig_legendaries),
        ("ig-hyc-08-binder-math.png", ig_binder_math),
        ("x-hyc-set-day-1600x900.png", x_set_day),
        ("story-1-opening-today.png", lambda: story([("OPENING", WHITE), ("HYPERIA CITY", GOLD), ("TODAY?", WHITE)], "vote below", "amber")),
        ("story-2-best-pull.png", lambda: story([("BEST PULL", WHITE), ("SO FAR?", GOLD)], "drop it below, we'll share the best ones", "amethyst")),
        ("story-3-master-set.png", lambda: story([("MASTER SET", GOLD), ("OR JUST", WHITE), ("THE MAIN 204?", WHITE)], "be honest", "sapphire")),
        ("story-4-first-ink.png", lambda: story([("WHICH INK", WHITE), ("ARE YOU", WHITE), ("BUILDING FIRST?", GOLD)], "amber, amethyst, emerald, ruby, sapphire or steel", "emerald")),
    ]
    only = set(sys.argv[1:])
    for i, (name, make) in enumerate(images):
        if only and name not in only and "images" not in only:
            continue
        finish(make(), 1400 + i).convert("RGB").save(OUT_IMAGES / name, optimize=True)
        print("image", name)
    for reel, build in REELS.items():
        if only and reel not in only and "reels" not in only:
            continue
        out = OUT_REELS / f"stills-{reel}"
        out.mkdir(parents=True, exist_ok=True)
        for i, make in enumerate(build(), 1):
            finish(make(), 1500 + i, count=160, stars=24).convert("RGB").save(out / f"{i:02d}.png", optimize=True)
        print("stills", reel)


main()
