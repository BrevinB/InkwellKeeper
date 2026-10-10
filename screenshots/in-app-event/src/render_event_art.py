#!/usr/bin/env python3
"""Hyperia City in-app event art for App Store Connect.

    python3 screenshots/in-app-event/src/render_event_art.py

Writes, next to this folder:
  * event-card-1920x1080.png     — event card (16:9)
  * event-details-1080x1920.png  — event details page (9:16)

Brand look (see the marketing-image-style notes): the in-app navy → plum gradient,
purple/blue glows, ink ribbons, gold sparkles, and six Hyperia City legendaries —
one per ink — fanned like a freshly opened pack. No text: the App Store lays the
event name and description over the bottom of the image, so that band stays dark.
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
OUT = HERE.parent

INK = {
    "amber": (244, 178, 35), "amethyst": (142, 59, 184), "emerald": (47, 168, 79),
    "ruby": (211, 40, 59), "sapphire": (31, 143, 214), "steel": (154, 165, 177),
}
CARDS = [  # one legendary per ink, left to right
    ("HYC-019.avif", INK["amber"]), ("HYC-055.avif", INK["amethyst"]), ("HYC-090.avif", INK["emerald"]),
    ("HYC-127.avif", INK["ruby"]), ("HYC-156.avif", INK["sapphire"]), ("HYC-196.avif", INK["steel"]),
]
GOLD = (255, 215, 0)


def gradient(w, h):
    """135° navy → plum → navy, the in-app LorcanaBackground."""
    stops = [(0.0, (13, 26, 51)), (0.5, (26, 13, 38)), (1.0, (13, 26, 51))]
    base = Image.new("RGB", (w, h))
    px = base.load()
    for y in range(h):
        for x in range(0, w, 2):
            t = (x / w + y / h) / 2
            for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
                if t0 <= t <= t1:
                    f = (t - t0) / (t1 - t0)
                    c = tuple(round(a + (b - a) * f) for a, b in zip(c0, c1))
                    break
            px[x, y] = c
            if x + 1 < w:
                px[x + 1, y] = c
    return base.convert("RGBA")


def glow(canvas, box, color, opacity, blur):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=color + (int(255 * opacity),))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def bezier(p0, p1, p2, p3, steps=120):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        pts.append((
            u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
        ))
    return pts


def ribbon(canvas, pts, color):
    """The app icon's ink ribbon: a wide soft glow under a thin bright stroke."""
    wide = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(wide).line(pts, fill=color + (70,), width=80, joint="curve")
    canvas.alpha_composite(wide.filter(ImageFilter.GaussianBlur(24)))
    thin = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(thin).line(pts, fill=color + (130,), width=7, joint="curve")
    canvas.alpha_composite(thin)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def card_sprite(file, ink, width):
    """A card with gold rim, sheen, and its ink-colored halo, on a transparent tile."""
    height = round(width * 88 / 63)
    radius = round(width * 0.048)
    face = Image.open(HERE / file).convert("RGBA").resize((width, height), Image.LANCZOS)
    # Diagonal sheen across the face.
    sheen = Image.new("L", (width, height), 0)
    ImageDraw.Draw(sheen).polygon([(width * .25, 0), (width * .45, 0), (width * .2, height), (0, height)], fill=60)
    face = Image.alpha_composite(face, Image.merge("RGBA", (*[Image.new("L", face.size, 255)] * 3, sheen.filter(ImageFilter.GaussianBlur(width * .06)))))
    face.putalpha(rounded_mask(face.size, radius))

    pad = round(width * 0.45)
    tile = Image.new("RGBA", (width + pad * 2, height + pad * 2), (0, 0, 0, 0))
    halo = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).rounded_rectangle((pad - 30, pad - 30, pad + width + 30, pad + height + 30), radius=radius * 3, fill=ink + (160,))
    tile.alpha_composite(halo.filter(ImageFilter.GaussianBlur(46)))
    shadow = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((pad, pad + 30, pad + width, pad + height + 30), radius=radius, fill=(0, 0, 0, 170))
    tile.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(30)))
    rim = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle((pad - 3, pad - 3, pad + width + 2, pad + height + 2), radius=radius + 3, fill=GOLD + (120,))
    tile.alpha_composite(rim)
    tile.alpha_composite(face, (pad, pad))
    return tile


def sparkles(canvas, seed, count, stars, max_y):
    rnd = random.Random(seed)
    w, _ = canvas.size
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for _ in range(count):
        x, y, r = rnd.random() * w, rnd.random() * max_y, 1.5 + rnd.random() * 4
        draw.ellipse((x - r, y - r, x + r, y + r), fill=GOLD + (int(255 * (.1 + rnd.random() * .25)),))
    for _ in range(stars):
        x, y, k = rnd.random() * w, rnd.random() * max_y, 10 + rnd.random() * 26
        o = int(255 * (.35 + rnd.random() * .5))
        pts = []
        for i in range(8):
            a = -math.pi / 2 + i * math.pi / 4
            rr = k if i % 2 == 0 else k * 0.18
            pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
        draw.polygon(pts, fill=(255, 226, 122, o))
    canvas.alpha_composite(layer)


def floor(canvas, height_fraction):
    """Darken the bottom for the App Store's text overlay."""
    w, h = canvas.size
    band = round(h * height_fraction)
    shade = Image.new("RGBA", (w, band), (9, 10, 24, 0))
    alpha = Image.linear_gradient("L").resize((w, band))
    shade.putalpha(alpha.point(lambda v: int(v * 0.92)))
    canvas.alpha_composite(shade, (0, h - band))


def render(layout):
    card = layout == "card"
    w, h = (1920, 1080) if card else (1080, 1920)
    canvas = gradient(w, h)
    if card:
        glow(canvas, (520, 60, 1420, 760), (128, 51, 204), .45, 140)
        glow(canvas, (1050, 200, 1850, 820), (31, 79, 168), .35, 140)
    else:
        glow(canvas, (40, 300, 1040, 1100), (128, 51, 204), .45, 140)
        glow(canvas, (160, 760, 1000, 1460), (31, 79, 168), .32, 140)

    card_w = 300 if card else 330
    card_h = round(card_w * 88 / 63)
    cx, cy = w / 2, (470 if card else 760)
    spread, tilt = (150, 9) if card else (118, 9)

    ry = cy - card_h * 0.15
    ribbon(canvas, bezier((-60, ry + 220), (w * .25, ry - 160), (w * .55, ry + 320), (w + 60, ry - 120)), INK["amethyst"])
    ribbon(canvas, bezier((-60, ry - 140), (w * .3, ry + 260), (w * .65, ry - 220), (w + 60, ry + 180)), INK["sapphire"])

    # Sparkles behind the cards, never on their art or text.
    sparkles(canvas, 20261016, 150 if card else 170, 22, h * (0.62 if card else 0.66))

    # Fan: outer cards first so the centre pair sits on top.
    order = sorted(range(6), key=lambda i: -abs(i - 2.5))
    for i in order:
        file, ink = CARDS[i]
        k = i - 2.5
        sprite = card_sprite(file, ink, card_w)
        # Rotate about a point below the card, like a fan held in a hand.
        rotated = sprite.rotate(-k * tilt, resample=Image.BICUBIC, expand=True)
        x = cx + k * spread
        y = cy + k * k * 14
        canvas.alpha_composite(rotated, (round(x - rotated.width / 2), round(y - rotated.height / 2)))

    floor(canvas, 0.42 if card else 0.36)
    out = OUT / ("event-card-1920x1080.png" if card else "event-details-1080x1920.png")
    canvas.convert("RGB").save(out, optimize=True)
    print("wrote", out.name, canvas.size)


if __name__ == "__main__":
    render("card")
    render("details")
