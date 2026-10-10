#!/usr/bin/env python3
"""Composite rendered storage-art layers the way the app does, for eyeballing renders.

    python3 Scripts/storage_art/preview_composite.py <render_dir> <out.png> [kind ...]

One row per kind and finish: four cover colors closed, then the same four with the
lid lifted using the kind's metrics, on the app's dark background.
"""

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

# StorageCoverColor.highlight
COLORS = {
    "amber": (0.96, 0.70, 0.25),
    "amethyst": (0.62, 0.40, 0.85),
    "ruby": (0.88, 0.28, 0.32),
    "ivory": (0.95, 0.91, 0.82),
}
BACKGROUND = (0x1B, 0x17, 0x2E, 255)
TILE_HEIGHT = 240


def tinted(directory, name, rgb):
    shade = Image.open(directory / f"{name}_shade.png").convert("RGBA")
    mask = Image.open(directory / f"{name}_mask.png").convert("RGBA").getchannel("A")
    color = Image.new("RGBA", shade.size, tuple(int(c * 255) for c in rgb) + (255,))
    multiplied = ImageChops.multiply(shade, color)
    multiplied.putalpha(shade.getchannel("A"))
    return Image.composite(multiplied, shade, mask)


def draw_card(frame, rect, angle):
    card = Image.new("RGBA", (int(rect[2]), int(rect[3])), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle(
        (0, 0, card.width - 1, card.height - 1), radius=card.width * 0.08,
        fill=(40, 30, 70, 255), outline=(230, 190, 90, 255), width=max(1, card.width // 25),
    )
    card = card.rotate(-angle, expand=True, resample=Image.BICUBIC)
    frame.alpha_composite(card, dest=(int(rect[0] + rect[2] / 2 - card.width / 2), int(rect[1] + rect[3] / 2 - card.height / 2)))


def compose(directory, kind, finish, rgb, lifted, metrics):
    base = tinted(directory, f"{kind}_base_{finish}", rgb)
    w, h = base.size
    frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    frame.alpha_composite(base)
    card_w = metrics.get("cardWidth", 0) * w
    card_h = card_w * 88 / 63
    has_lid = (directory / f"{kind}_lid_{finish}_shade.png").exists()
    if card_w and (lifted or not has_lid):
        rim = metrics["rimY"] * h
        cards = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        if has_lid:
            for offset in (-0.9, 0.0, 0.9):
                rise = (rim + card_h * 0.05 - metrics["cardPeakY"] * h) * (1 if offset == 0 else 0.8)
                draw_card(cards, (w / 2 - card_w / 2 + offset * card_w * 0.6, rim + card_h * 0.05 - rise, card_w, card_h), offset * 9)
        else:
            left, right = metrics["openingLeft"] * w, metrics["openingRight"] * w
            for i, (t, tilt) in enumerate(((0.15, -18), (0.38, 8), (0.62, -6), (0.85, 16))):
                top = rim - card_h * (0.55 if i % 2 == 0 else 0.7)
                draw_card(cards, (left + (right - left) * t - card_w / 2, top, card_w, card_h), tilt)
        band = Image.new("L", (w, h), 0)
        ImageDraw.Draw(band).rectangle((0, 0, w, metrics["bottomY"] * h), fill=255)
        frame.paste(cards, (0, 0), ImageChops.multiply(cards.getchannel("A"), band))
        front = base.copy()
        cut = Image.new("L", (w, h), 0)
        ImageDraw.Draw(cut).rectangle((0, metrics["rimY"] * h, w, h), fill=255)
        front.putalpha(ImageChops.multiply(front.getchannel("A"), cut))
        frame.alpha_composite(front)
    if has_lid:
        lid = tinted(directory, f"{kind}_lid_{finish}", rgb)
        if lifted:
            hinge = (metrics["lidHingeX"] * w, metrics["lidHingeY"] * h)
            lid = lid.rotate(4, center=hinge, resample=Image.BICUBIC)
            moved = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            moved.alpha_composite(lid, dest=(0, -int(metrics["lidRise"] * h)))
            lid = moved
        frame.alpha_composite(lid)
    return frame


def main():
    directory, out = Path(sys.argv[1]), Path(sys.argv[2])
    kinds = sys.argv[3:] or sorted(p.name.removesuffix("_metrics.json") for p in directory.glob("*_metrics.json"))
    rows = []
    for kind in kinds:
        metrics = json.loads((directory / f"{kind}_metrics.json").read_text())
        for finish in ("classic", "stitched"):
            if not (directory / f"{kind}_base_{finish}_shade.png").exists():
                continue
            tiles = [compose(directory, kind, finish, rgb, lifted, metrics) for lifted in (False, True) for rgb in COLORS.values()]
            rows.append(tiles)
    tile_w = max(math.ceil(t.width * TILE_HEIGHT / t.height) for row in rows for t in row)
    sheet = Image.new("RGBA", (tile_w * 8, TILE_HEIGHT * len(rows)), BACKGROUND)
    for r, row in enumerate(rows):
        for c, tile in enumerate(row):
            scaled = tile.resize((round(tile.width * TILE_HEIGHT / tile.height), TILE_HEIGHT), Image.LANCZOS)
            sheet.alpha_composite(scaled, dest=(c * tile_w + (tile_w - scaled.width) // 2, r * TILE_HEIGHT))
    sheet.save(out)


main()
