#!/usr/bin/env python3
""""Android is coming" + beta-tester recruiting images.

    /opt/homebrew/bin/python3.14 marketing/android/src/make_coming_soon.py

Writes to marketing/drafts/images/android-coming-soon/ (gitignored):
  ig-1-coming.png     1080×1350  announcement
  ig-2-testers.png    1080×1350  "I need 12 beta testers" (number-led)
  ig-3-features.png   1080×1350  three screens, everything you use on iPhone
  story-beta.png      1080×1920  story / TikTok cover
  x-coming.png        1600×900   X / Reddit / Discord

Screens are real captures from the Android build (Pixel emulator, demo collection),
kept in marketing/drafts/images/android-coming-soon/captures/. Brand helpers come
from the 3.5 launch script so the look matches the iOS posts.
"""

import sys
import types
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "marketing/drafts/images/android-coming-soon"
CAPTURES = OUT / "captures"

# make_launch_images.py renders its own images on import, so load only its helper section
# (everything above the "Feed images" banner) into a fresh module.
_src_path = ROOT / "marketing/3.5/src/make_launch_images.py"
_helpers = _src_path.read_text().split("# Feed images")[0].rsplit("\n#", 1)[0]
L = types.ModuleType("launch_helpers")
L.__file__ = str(_src_path)
exec(compile(_helpers, str(_src_path), "exec"), L.__dict__)
INK = L.event_art.INK

# Captures are 1080×2424; skip the status bar, keep the app chrome below it.
FULL = (0, 150, 1080, 2424)
TOP = (0, 150, 1080, 1700)


def cap(name):
    return CAPTURES / f"{name}.png"


def ig_coming():
    c = L.background(1080, 1350, INK["emerald"], 700)
    y = L.text_center(c, 64, "INK WELL KEEPER", L.HEAVY, 76, L.SOFT, tracking=6)
    y = L.text_center(c, y + 6, "IS COMING TO", L.HEAVY, 128, L.WHITE, max_width=960)
    L.text_center(c, y - 6, "Android", L.ITALIC, 150, L.GOLD)
    tile, _ = L.screen(cap("01-collection"), (0, 150, 1080, 1500), 520)
    L.place_center(c, tile, 540, 440)
    L.cta(c, 1236, "Beta testers wanted · link in bio")
    return L.finish(c, 41)


def ig_testers():
    c = L.background(1080, 1350, INK["amethyst"], 1130)
    L.text_center(c, 120, "I NEED", L.HEAVY, 110, L.WHITE)
    y = L.text_center(c, 200, "12", L.HEAVY, 420, L.GOLD)
    y = L.text_center(c, y + 10, "Android", L.ITALIC, 110, L.WHITE)
    y = L.text_center(c, y + 4, "BETA TESTERS", L.HEAVY, 110, L.WHITE, max_width=960)
    y = L.text_center(c, y + 40, "Google needs 12 testers for 14 days", L.DEMI, 40, L.SOFT)
    L.text_center(c, y + 10, "before Ink Well Keeper can launch on Play.", L.DEMI, 40, L.SOFT)
    L.cta(c, 1180, "Join the beta · link in bio")
    return L.finish(c, 42)


def ig_features():
    c = L.background(1080, 1350, INK["sapphire"], 760)
    y = L.text_center(c, 60, "SAME APP.", L.HEAVY, 116, L.WHITE)
    L.text_center(c, y - 4, "new home", L.ITALIC, 84, L.GOLD)
    left, _ = L.screen(cap("04-stats"), TOP, 360, radius=32)
    right, _ = L.screen(cap("05-set"), TOP, 360, radius=32)
    mid, _ = L.screen(cap("02-card"), TOP, 420, radius=36)
    c.alpha_composite(left.rotate(6, resample=Image.BICUBIC, expand=True), (-10, 400))
    c.alpha_composite(right.rotate(-6, resample=Image.BICUBIC, expand=True), (590, 400))
    L.place_center(c, mid, 540, 320)
    L.text_center(c, 1150, "Scan · Track · Price history · Decks · Binders", L.DEMI, 38, L.SOFT, max_width=980)
    L.cta(c, 1225, "Android beta · link in bio")
    return L.finish(c, 43)


def story_beta():
    c = L.background(1080, 1920, INK["emerald"], 1100)
    y = L.text_center(c, 150, "ANDROID", L.HEAVY, 190, L.WHITE)
    L.text_center(c, y - 10, "beta is open", L.ITALIC, 120, L.GOLD)
    tile, _ = L.screen(cap("01-collection"), FULL, 640)
    L.place_center(c, tile, 540, 560)
    return L.finish(c, 44)


def x_coming():
    c = L.background(1600, 900, INK["emerald"], 520)
    draw_w = 860
    # Left-aligned text block: reuse text_center on a narrow canvas, then paste.
    block = Image.new("RGBA", (draw_w, 900), (0, 0, 0, 0))
    y = L.text_center(block, 150, "INK WELL KEEPER", L.HEAVY, 54, L.SOFT, tracking=4)
    y = L.text_center(block, y + 8, "IS COMING TO", L.HEAVY, 96, L.WHITE, max_width=800)
    y = L.text_center(block, y - 6, "Android", L.ITALIC, 140, L.GOLD)
    y = L.text_center(block, y + 30, "Looking for 12+ beta testers", L.DEMI, 40, L.SOFT)
    L.cta(block, y + 30, "Join the beta")
    L.text_layer(c).alpha_composite(L.text_layer(block), (60, 0))
    tile, _ = L.screen(cap("01-collection"), (0, 150, 1080, 1850), 520, radius=36)
    c.alpha_composite(tile.rotate(-4, resample=Image.BICUBIC, expand=True), (910, 40))
    return L.finish(c, 45, count=140, stars=22)


RENDERS = {
    "ig-1-coming": ig_coming,
    "ig-2-testers": ig_testers,
    "ig-3-features": ig_features,
    "story-beta": story_beta,
    "x-coming": x_coming,
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name in sys.argv[1:] or RENDERS:
        RENDERS[name]().convert("RGB").save(OUT / f"{name}.png")
        print("wrote", OUT / f"{name}.png")
