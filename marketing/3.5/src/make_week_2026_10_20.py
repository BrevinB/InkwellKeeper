#!/usr/bin/env python3
"""Instagram/X images for the week of Oct 20–26, 2026 (first week after Hyperia City).

    python3 marketing/3.5/src/make_week_2026_10_20.py [<file name> ...]

Writes 1080×1350 feed images and a 1600×900 X image to
marketing/drafts/images/2026-10-20/. Reuses the set-day helpers (and through
them the 3.5 launch brand helpers) from make_hyperia_images.py.

Prices are a frozen snapshot from our pricing backend (Lorcast USD foil, daily
06:00 UTC rows, Sat Oct 17 → Mon Oct 19) so the image matches its caption.
"""

import sys
from pathlib import Path

from PIL import ImageDraw

HERE = Path(__file__).resolve().parent

# Load the set-day helpers without running that script's main().
_source = (HERE / "make_hyperia_images.py").read_text().rsplit("\nmain()", 1)[0]
hyc = {"__file__": str(HERE / "make_hyperia_images.py"), "__name__": "hyc"}
exec(compile(_source, "make_hyperia_images.py", "exec"), hyc)
brand, event_art, CARDS = hyc["brand"], hyc["event_art"], hyc["CARDS"]
finish, place, sprite = hyc["finish"], hyc["place"], hyc["sprite"]
text_center, cta, background = hyc["text_center"], hyc["cta"], hyc["background"]
HEAVY, DEMI, ITALIC = hyc["HEAVY"], hyc["DEMI"], hyc["ITALIC"]
WHITE, GOLD, SOFT = hyc["WHITE"], hyc["GOLD"], hyc["SOFT"]
font, text_layer = brand["font"], brand["text_layer"]

OUT_IMAGES = hyc["ROOT"] / "marketing/drafts/images/2026-10-20"

# The five most valuable Enchanteds on Mon Oct 19: (collector number, Sat 17, Mon 19).
TOP_ENCHANTEDS = [(236, 1112.48, 466.75), (230, 451.99, 394.50), (223, 634.00, 340.50),
                  (226, 749.75, 330.99), (229, 250.00, 278.79)]
MEDIAN_ENCHANTED_CHANGE = "−54%"  # median of all 18 Enchanteds, same window


def thumb(n, width):
    """A card sprite cropped to its gold rim: at thumbnail size the ink halo bleeds into a visible box."""
    tile, pad = sprite(n, width), round(width * .45)
    return tile.crop((pad - 4, pad - 4, tile.width - pad + 4, tile.height - pad + 4))


def ig_enchanted_prices():
    """Number-led: the median weekend move, then the top five with Sat → Mon prices."""
    c = background(1080, 1350, event_art.INK["sapphire"], 1330)
    y = text_center(c, 40, MEDIAN_ENCHANTED_CHANGE, HEAVY, 300, GOLD, max_width=900)
    y = text_center(c, y - 4, "ENCHANTED PRICES, SAT TO MON", HEAVY, 64, WHITE, tracking=2, max_width=960)
    text_center(c, y + 8, "launch-weekend prices are still settling", ITALIC, 46, SOFT, max_width=960)
    d = ImageDraw.Draw(text_layer(c))
    f_name, f_old, f_new = font(DEMI, 34), font(DEMI, 30), font(HEAVY, 52)
    top, step = 560, 124
    for i, (n, sat, mon) in enumerate(TOP_ENCHANTEDS):
        ry = top + i * step
        d.rounded_rectangle((90, ry - 8, 990, ry + 104), radius=26, fill=(255, 255, 255, 20))
        place(c, thumb(n, 70), 155, ry + 48)
        d.text((220, ry + 8), CARDS[n]["name"], font=f_name, fill=WHITE)
        d.text((220, ry + 54), f"Sat ${sat:,.0f}", font=f_old, fill=SOFT)
        value = f"${mon:,.0f}"
        w = d.textlength(value, font=f_new)
        d.text((954 - w, ry + 20), value, font=f_new, fill=GOLD)
    text_center(c, top + 5 * step + 6, "Lorcast market, foil · Oct 17 to Oct 19", DEMI, 28, SOFT, max_width=960)
    cta(c, 1250, "Price history on every card · Free on iOS")
    return c


def all_242(w, h):
    """Build-in-public: the 3.5.1 data update added the 18 Epics and 18 Enchanteds."""
    c = background(w, h, event_art.INK["amethyst"], h * .8)
    wide = w > h
    y = text_center(c, 50 if wide else 60, "ALL 242 ARE IN", HEAVY, 120 if wide else 136, WHITE, max_width=w - 140)
    text_center(c, y + 8, "every Hyperia City Epic & Enchanted, ready to check off", ITALIC,
                50 if wide else 46, GOLD, max_width=w - 140)
    fan = [212, 236, 223, 230, 215] if wide else [212, 226, 236, 230, 215]  # Epic, Enchanted ×3, Epic
    width, spread = (250, 230) if wide else (340, 175)
    cy = 600 if wide else 760
    for i in sorted(range(len(fan)), key=lambda i: -abs(i - 2)):
        k = i - 2
        place(c, sprite(fan[i], width, rotate=-k * 9), w / 2 + k * spread, cy + k * k * 20)
    if not wide:
        cta(c, 1240, "Update Ink Well Keeper · Free on iOS")
    return c


# Sorting-tip carousel: cover, then one slide per pile.
PILES = [
    ("1", "THE SET BINDER", "one of each number",
     ["Sort by collector number before you sleeve.",
      "Epics, Enchanteds & Iconics (#205–242)",
      "get their own pages at the back, so a late",
      "pull never shifts your layout."], [55, 90, 156], "emerald"),
    ("2", "PLAYSETS", "copies 2–4 of anything you'd play",
     ["Keep them in a box or deck box, not the binder.",
      "Pulling cards out of binder pages for decks",
      "is how binders end up with holes",
      "nobody remembers."], [3, 14, 125], "ruby"),
    ("3", "BULK", "everything else",
     ["Band it by ink and write the set on the box.",
      "One more thing: foil and normal are two",
      "different cards with two different prices.",
      "Track them separately."], [1, 2, 84], "steel"),
]


def ig_sort_cover():
    c = background(1080, 1350, event_art.INK["amber"], 1100)
    y = text_center(c, 70, "SORT YOUR PULLS", HEAVY, 128, WHITE, max_width=960)
    y = text_center(c, y + 2, "IN 3 PILES", HEAVY, 128, GOLD, max_width=960)
    text_center(c, y + 14, "before you sleeve a single card", ITALIC, 54, GOLD, max_width=960)
    for p, (_, label, _, _, cards, _) in enumerate(PILES):
        cx = 220 + p * 320
        for j, n in enumerate(cards):
            place(c, sprite(n, 220, rotate=(j - 1) * 7), cx + (j - 1) * 14, 860 - j * 14)
        text_center_at(c, cx, 1060, label, DEMI, 32, WHITE)
    text_center(c, 1250, "swipe for the system", DEMI, 34, SOFT)
    return c


def text_center_at(canvas, cx, y, text, spec, size, fill):
    d = ImageDraw.Draw(text_layer(canvas))
    f = font(spec, size)
    d.text((cx - d.textlength(text, font=f) / 2, y), text, font=f, fill=fill)


def ig_sort_pile(i):
    number, label, sub, body, cards, tone = PILES[i]
    c = background(1080, 1350, event_art.INK[tone], 1210)
    d = ImageDraw.Draw(text_layer(c))
    d.text((90, 30), number, font=font(HEAVY, 380), fill=GOLD)
    d.text((330, 130), "PILE", font=font(HEAVY, 64), fill=SOFT)
    d.text((330, 196), label, font=font(HEAVY, 104), fill=WHITE)
    d.text((334, 320), sub, font=font(ITALIC, 46), fill=GOLD)
    for j, n in enumerate(cards):
        place(c, sprite(n, 250, rotate=(j - 1) * 8), 540 + (j - 1) * 230, 690 + abs(j - 1) * 24)
    for k, line in enumerate(body):
        text_center(c, 960 + k * 54, line, DEMI, 38, WHITE if k else GOLD, max_width=960)
    if i == len(PILES) - 1:
        cta(c, 1250, "Track every binder & box · Free on iOS")
    return c


def main():
    OUT_IMAGES.mkdir(parents=True, exist_ok=True)
    images = [
        ("ig-01-enchanted-prices.png", ig_enchanted_prices),
        ("ig-02-all-242.png", lambda: all_242(1080, 1350)),
        ("x-all-242-1600x900.png", lambda: all_242(1600, 900)),
        ("ig-03a-sort-cover.png", ig_sort_cover),
        ("ig-03b-pile-binder.png", lambda: ig_sort_pile(0)),
        ("ig-03c-pile-playsets.png", lambda: ig_sort_pile(1)),
        ("ig-03d-pile-bulk.png", lambda: ig_sort_pile(2)),
    ]
    only = set(sys.argv[1:])
    for i, (name, make) in enumerate(images):
        if only and name not in only:
            continue
        finish(make(), 2000 + i).convert("RGB").save(OUT_IMAGES / name, optimize=True)
        print("image", name)


main()
