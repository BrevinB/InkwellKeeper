#!/usr/bin/env python3
"""Starlight & Holofoil cover reel (the Pro finishes; storageTheme is the top-converting paywall).

    python3 marketing/3.5/src/make_covers_reel.py

Renders every frame in Pillow and pipes them to ffmpeg, writing
marketing/drafts/reels/2026-10-16/reel-covers-pro-finishes.mp4 (1080×1920, 30fps, silent).

The finishes follow the app's own views so the reel shows what Pro buyers get:
- Starlight (StarlightFinish.swift): 16 gold four-point sparkles, every 4th one larger,
  twinkling with sin(t·1.8 + phase).
- Holofoil (HolofoilFinish.swift): a two-cycle diagonal spectrum overlay-blended at 60%,
  plus a white glint screen-blended. It's static in the app, so it's static here too;
  only the cover floats.
Every finish also gets the shared top-left sheen from CoverFinishOverlay.swift.
"""

import math
import random
import subprocess
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "marketing/drafts/reels/2026-10-16/reel-covers-pro-finishes.mp4"
FPS = 30
W, H = 1080, 1920

# Load the 3.5 launch helpers without running that script's main().
_source = (HERE / "make_launch_images.py").read_text().rsplit("\nmain()", 1)[0]
brand = {"__file__": str(HERE / "make_launch_images.py"), "__name__": "brand"}
exec(compile(_source, "make_launch_images.py", "exec"), brand)
event_art = brand["event_art"]
text_center, cta, background = brand["text_center"], brand["cta"], brand["background"]
HEAVY, DEMI, ITALIC = brand["HEAVY"], brand["DEMI"], brand["ITALIC"]
WHITE, GOLD, SOFT = brand["WHITE"], brand["GOLD"], brand["SOFT"]
COVER_COLORS = brand["COVER_COLORS"]

SPECTRUM = [(255, 115, 191), (255, 217, 89), (115, 255, 179), (89, 217, 255), (166, 115, 255)]


# ---------------------------------------------------------------------------
# Finishes
# ---------------------------------------------------------------------------


def diagonal_lut(stops, inset=0.0):
    """256-entry RGBA lookup along the top-left → bottom-right diagonal.

    `stops` are (location, (r, g, b), alpha 0–1); `inset` widens the gradient past the
    corners the way SwiftUI's UnitPoint(-0.15, -0.15)…(1.15, 1.15) does.
    """
    lut = []
    for i in range(256):
        t = (i / 255 + inset) / (1 + 2 * inset)
        for (l0, c0, a0), (l1, c1, a1) in zip(stops, stops[1:]):
            if l0 <= t <= l1:
                k = 0 if l1 == l0 else (t - l0) / (l1 - l0)
                lut.append(tuple(round(c0[j] + (c1[j] - c0[j]) * k) for j in range(3)) + (round(255 * (a0 + (a1 - a0) * k)),))
                break
        else:
            lut.append((0, 0, 0, 0))
    return lut


def diagonal_layer(size, lut):
    w, h = size
    u = Image.linear_gradient("L").rotate(90).resize((w, h))  # left → right
    v = Image.linear_gradient("L").resize((w, h))  # top → bottom
    t = ImageChops.add(u, v, scale=2)  # (u + v) / 2
    return Image.merge("RGBA", [t.point([entry[ch] for entry in lut]) for ch in range(4)])


def spectrum_stops():
    stops = []
    for cycle in range(2):
        start = cycle * 0.5
        stops.append((start, SPECTRUM[0], 0))
        for index, color in enumerate(SPECTRUM):
            local = 0.12 + 0.76 * index / (len(SPECTRUM) - 1)
            stops.append((start + local * 0.5, color, math.sin(math.pi * local)))
        stops.append((start + 0.5, SPECTRUM[-1], 0))
    return stops


def with_sheen(cover):
    sheen = diagonal_layer(cover.size, diagonal_lut([(0, (255, 255, 255), .28), (.5, (255, 255, 255), 0), (1, (255, 255, 255), 0)]))
    out = cover.copy()
    out.alpha_composite(sheen)
    out.putalpha(cover.getchannel("A"))
    return out


def holofoil(cover):
    rgb = cover.convert("RGB")
    spectrum = diagonal_layer(cover.size, diagonal_lut(spectrum_stops(), inset=.15))
    blended = ImageChops.overlay(rgb, spectrum.convert("RGB"))
    rgb = Image.composite(blended, rgb, spectrum.getchannel("A").point(lambda a: round(a * .6)))
    glint = diagonal_layer(cover.size, diagonal_lut([(0, (255, 255, 255), 0), (.18, (255, 255, 255), 0), (.32, (255, 255, 255), .38), (.48, (255, 255, 255), 0), (1, (255, 255, 255), 0)]))
    rgb = Image.composite(ImageChops.screen(rgb, glint.convert("RGB")), rgb, glint.getchannel("A"))
    out = rgb.convert("RGBA")
    out.putalpha(cover.getchannel("A"))
    return with_sheen(out)


class Starlight:
    """The twinkling sparkle layer, re-drawn per frame."""

    def __init__(self, cover):
        self.cover = with_sheen(cover)
        rnd = random.Random(42)
        w, h = cover.size
        # Keep stars on the cover face, not out in its transparent margins.
        alpha = cover.getchannel("A")
        self.stars = []
        while len(self.stars) < 16:
            x, y = rnd.uniform(0, w), rnd.uniform(0, h)
            if alpha.getpixel((min(w - 1, int(x)), min(h - 1, int(y)))) < 200:
                continue
            index = len(self.stars)
            base = min(w, h) * (.09 if index % 4 == 0 else .04)
            self.stars.append((x, y, rnd.uniform(0, 2 * math.pi), base))

    def frame(self, t):
        out = self.cover.copy()
        layer = Image.new("RGBA", out.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for x, y, phase, base in self.stars:
            twinkle = (math.sin(t * 1.8 + phase) + 1) / 2
            outer = base * (.6 + .4 * twinkle) / 2
            inner = outer * .22
            pts = [(x + math.cos(i * math.pi / 4 - math.pi / 2) * (outer if i % 2 == 0 else inner),
                    y + math.sin(i * math.pi / 4 - math.pi / 2) * (outer if i % 2 == 0 else inner)) for i in range(8)]
            d.polygon(pts, fill=GOLD + (round(255 * (.35 + .55 * twinkle)),))
        out.alpha_composite(layer)
        return out


def cover(color, width, finish):
    base = brand["binder_cover"](COVER_COLORS[color], "classic", width)
    if finish == "holofoil":
        return holofoil(base)
    return Starlight(base)


# ---------------------------------------------------------------------------
# Scenes: a static backdrop (text + sparkles kept clear of the covers) + floating covers
# ---------------------------------------------------------------------------


def backdrop(build_text, cover_boxes, tone, seed):
    c = background(W, H, event_art.INK[tone], 1640)
    bare = c.copy()
    build_text(c)
    layer = brand["text_layer"](c)
    keep = layer.getchannel("A").point(lambda v: 255 if v > 8 else 0)
    d = ImageDraw.Draw(keep)
    for box in cover_boxes:
        d.rectangle(box, fill=255)
    keep = keep.filter(ImageFilter.MaxFilter(41)).filter(ImageFilter.MaxFilter(41))
    spark = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    event_art.sparkles(spark, seed, 150, 22, H)
    spark.putalpha(ImageChops.multiply(spark.getchannel("A"), ImageChops.invert(keep)))
    out = bare
    out.alpha_composite(spark)
    out.alpha_composite(layer)
    return out


def shadowed(img):
    return brand["drop_shadowed"](img, blur=30, offset=26, alpha=190)


def render_scene(seconds, build_text, covers, tone, seed):
    """covers: list of (cover object or image, centre x, centre y, float phase)."""
    sized = [(obj, cx, cy, ph, (obj.cover if isinstance(obj, Starlight) else obj).size) for obj, cx, cy, ph in covers]
    boxes = [(cx - w / 2, cy - h / 2 - 20, cx + w / 2, cy + h / 2 + 20) for _, cx, cy, _, (w, h) in sized]
    base = backdrop(build_text, boxes, tone, seed)
    static = {id(obj): shadowed(obj) for obj, *_ in sized if not isinstance(obj, Starlight)}
    for f in range(round(seconds * FPS)):
        t = f / FPS
        frame = base.copy()
        for obj, cx, cy, ph, _ in sized:
            tile = shadowed(obj.frame(t)) if isinstance(obj, Starlight) else static[id(obj)]
            dy = 12 * math.sin(2 * math.pi * t / 3.2 + ph)
            frame.alpha_composite(tile, (round(cx - tile.width / 2), round(cy - tile.height / 2 + dy)))
        yield frame.convert("RGB")


def scenes():
    # 1 — title, a holofoil cover rising behind the hook
    def title(c):
        y = text_center(c, 150, "YOUR BINDER,", HEAVY, 150, WHITE, max_width=960)
        y = text_center(c, y + 4, "BUT MAKE IT", HEAVY, 150, WHITE, max_width=960)
        text_center(c, y + 4, "HOLOFOIL", HEAVY, 170, GOLD, max_width=960)
    yield from render_scene(2.4, title, [(cover("amethyst", 600, "holofoil"), 540, 1240, 0)], "amethyst", 11)

    # 2 — Starlight, twinkling
    def starlight_text(c):
        y = text_center(c, 170, "STARLIGHT", HEAVY, 170, WHITE, max_width=960)
        text_center(c, y + 10, "a binder that twinkles on your shelf", ITALIC, 58, GOLD, max_width=960)
    yield from render_scene(3.6, starlight_text, [(cover("midnight", 640, "starlight"), 540, 1150, 0)], "sapphire", 12)

    # 3 — Holofoil
    def holo_text(c):
        y = text_center(c, 170, "HOLOFOIL", HEAVY, 170, WHITE, max_width=960)
        text_center(c, y + 10, "rainbow foil on any colour", ITALIC, 58, GOLD, max_width=960)
    yield from render_scene(3.2, holo_text, [(cover("sapphire", 640, "holofoil"), 540, 1150, 0)], "sapphire", 13)

    # 4 — a row of mixed covers
    def row_text(c):
        y = text_center(c, 170, "8 COLOURS", HEAVY, 150, WHITE, max_width=960)
        text_center(c, y + 10, "both finishes on every one", ITALIC, 58, GOLD, max_width=960)
    row = [(cover("ruby", 360, "starlight"), 300, 900, 0), (cover("ivory", 360, "holofoil"), 780, 900, 1.6),
           (cover("emerald", 360, "holofoil"), 300, 1440, 3.1), (cover("amber", 360, "starlight"), 780, 1440, 4.7)]
    yield from render_scene(3.4, row_text, row, "emerald", 14)

    # 5 — end card
    def end(c):
        y = text_center(c, 300, "MAKE IT", HEAVY, 160, WHITE, max_width=960)
        y = text_center(c, y + 4, "YOURS", HEAVY, 160, GOLD, max_width=960)
        text_center(c, y + 20, "Starlight & Holofoil come with Pro", ITALIC, 56, GOLD, max_width=960)
        text_center(c, 1560, "INK WELL KEEPER", HEAVY, 80, WHITE, max_width=960)
        cta(c, 1680, "Free on iOS")
    yield from render_scene(2.8, end, [(cover("amethyst", 420, "starlight"), 540, 1080, 0)], "amber", 15)


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    ffmpeg = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
         "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUT)],
        stdin=subprocess.PIPE)
    for n, frame in enumerate(scenes()):
        ffmpeg.stdin.write(frame.tobytes())
        if n % 60 == 0:
            print("frame", n, flush=True)
    ffmpeg.stdin.close()
    ffmpeg.wait()
    print("wrote", OUT)


main()
