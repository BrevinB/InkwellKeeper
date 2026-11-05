#!/usr/bin/python3
"""
compose_duo.py — iPhone Duo App Store screenshot scaffolds.

Same recipe as the ASO skill's compose.py (headline above a device showing the
capture, the device bleeding off the bottom edge), sized for
the two iPhone Duo slots in App Store Connect:

    unfolded  2853 × 2007  (landscape — the inner display opens like a passport)
    folded    1398 × 2034  (portrait — the outer display)

The default background is the app theme used on the social posts: the in-app
LorcanaBackground diagonal navy→plum gradient with faint gold sparkles and a soft
purple glow. Pass --style flat for the old solid #151421.

Run with /usr/bin/python3 (the interpreter with Pillow on this Mac):

    /usr/bin/python3 compose_duo.py --layout unfolded --verb TRACK \
        --desc "YOUR COLLECTION'S VALUE" --screenshot capture.png --output scaffold.png
"""

import argparse
import math
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_PATH = "/Library/Fonts/SF-Pro-Display-Black.otf"
BRAND_BG = "#151421"

# LorcanaBackground: 135° gradient #0D1A33 → #1A0D26 → #0D1A33.
THEME_STOPS = [(0.0, (0x0D, 0x1A, 0x33)), (0.5, (0x1A, 0x0D, 0x26)), (1.0, (0x0D, 0x1A, 0x33))]
GOLD = (0xFF, 0xD7, 0x00)
PURPLE_GLOW = (0x80, 0x33, 0xCC)

# Per-slot layout. Type sizes follow the iPhone set's proportions (verb ≈ 9% and
# descriptor ≈ 4.4% of the canvas's shorter side).
LAYOUTS = {
    "unfolded": dict(
        canvas=(2853, 2007), verb_max=210, verb_min=150, desc=104, text_top=120,
        max_text_w=0.70, device_w=2240, device_y=560, bezel=26, corner=96,
    ),
    "folded": dict(
        canvas=(1398, 2034), verb_max=200, verb_min=130, desc=92, text_top=130,
        max_text_w=0.86, device_w=1120, device_y=560, bezel=22, corner=110,
    ),
}
VERB_DESC_GAP = 22
DESC_LINE_GAP = 20


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def gradient_color(t):
    for (t0, c0), (t1, c1) in zip(THEME_STOPS, THEME_STOPS[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            return tuple(round(a + (b - a) * f) for a, b in zip(c0, c1))
    return THEME_STOPS[-1][1]


def theme_background(size):
    """Diagonal gradient from the top-left corner to the bottom-right corner."""
    w, h = size
    small_w, small_h = max(2, w // 8), max(2, h // 8)
    small = Image.new("RGB", (small_w, small_h))
    small.putdata([
        gradient_color((x / (small_w - 1) + y / (small_h - 1)) / 2)
        for y in range(small_h) for x in range(small_w)
    ])
    return small.resize(size, Image.BICUBIC).convert("RGBA")


def purple_glow(size, center, radius, alpha):
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    cx, cy = center
    ImageDraw.Draw(glow).ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                                 fill=(*PURPLE_GLOW, alpha))
    return glow.filter(ImageFilter.GaussianBlur(radius * 0.6))


def four_point_star(draw, cx, cy, r, alpha):
    waist = r * 0.22
    points = []
    for k in range(8):
        angle = math.pi / 4 * k - math.pi / 2
        dist = r if k % 2 == 0 else waist
        points.append((cx + dist * math.cos(angle), cy + dist * math.sin(angle)))
    draw.polygon(points, fill=(*GOLD, alpha))


def sparkle_field(size, keep_out, seed, scale):
    """Seeded gold dots plus a few four-point stars, kept clear of the text and device."""
    rng = random.Random(seed)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    w, h = size

    def clear(x, y, pad):
        return all(not (l - pad <= x <= r + pad and t - pad <= y <= b + pad) for l, t, r, b in keep_out)

    placed, attempts = 0, 0
    while placed < 70 and attempts < 4000:
        attempts += 1
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        if not clear(x, y, 24 * scale):
            continue
        r = rng.uniform(2, 5) * scale
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(*GOLD, round(255 * rng.uniform(0.10, 0.30))))
        placed += 1

    stars, attempts = 0, 0
    while stars < 7 and attempts < 4000:
        attempts += 1
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        if not clear(x, y, 60 * scale):
            continue
        four_point_star(draw, x, y, rng.uniform(14, 30) * scale, round(255 * rng.uniform(0.25, 0.5)))
        stars += 1

    glow = layer.filter(ImageFilter.GaussianBlur(6 * scale))
    return Image.alpha_composite(glow, layer)


def word_wrap(draw, text, font, max_w):
    lines, current = [], ""
    for word in text.split():
        candidate = f"{current} {word}".strip()
        if draw.textlength(candidate, font=font) <= max_w:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def fit_font(text, max_w, size_max, size_min):
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    for size in range(size_max, size_min - 1, -4):
        font = ImageFont.truetype(FONT_PATH, size)
        left, _, right, _ = probe.textbbox((0, 0), text, font=font)
        if right - left <= max_w:
            return font
    return ImageFont.truetype(FONT_PATH, size_min)


def draw_centered(draw, canvas_w, y, text, font, max_w):
    for line in word_wrap(draw, text, font, max_w):
        _, top, _, bottom = draw.textbbox((0, 0), line, font=font)
        draw.text((canvas_w // 2, y - top), line, fill="white", font=font, anchor="mt")
        y += (bottom - top) + DESC_LINE_GAP
    return y


def compose(layout_name, style, bg_hex, verb, desc, screenshot_path, output_path):
    layout = LAYOUTS[layout_name]
    canvas_w, canvas_h = layout["canvas"]
    max_text_w = int(canvas_w * layout["max_text_w"])

    # Device geometry first, so the sparkle field can keep clear of it.
    shot = Image.open(screenshot_path).convert("RGBA")
    bezel = layout["bezel"]
    device_w = layout["device_w"]
    screen_w = device_w - 2 * bezel
    screen_h = round(shot.height * screen_w / shot.width)
    device_h = screen_h + 2 * bezel
    device_x = (canvas_w - device_w) // 2
    device_y = layout["device_y"]
    corner = layout["corner"]

    if style == "theme":
        canvas = theme_background((canvas_w, canvas_h))
        glow_r = int(min(canvas_w, canvas_h) * 0.38)
        canvas = Image.alpha_composite(canvas, purple_glow(canvas.size, (device_x, device_y + glow_r // 2), glow_r, 70))
        canvas = Image.alpha_composite(canvas, purple_glow(canvas.size, (device_x + device_w, canvas_h), glow_r, 60))
        text_box = ((canvas_w - max_text_w) // 2, 0, (canvas_w + max_text_w) // 2, device_y - 40)
        device_box = (device_x, device_y, device_x + device_w, canvas_h)
        scale = min(canvas_w, canvas_h) / 1400
        canvas = Image.alpha_composite(canvas, sparkle_field(canvas.size, [text_box, device_box], verb, scale))
    else:
        canvas = Image.new("RGBA", (canvas_w, canvas_h), (*hex_to_rgb(bg_hex), 255))
    draw = ImageDraw.Draw(canvas)

    # Headline: verb biggest, descriptor smaller, both inside the central safe area.
    verb_font = fit_font(verb.upper(), max_text_w, layout["verb_max"], layout["verb_min"])
    desc_font = ImageFont.truetype(FONT_PATH, layout["desc"])
    y = draw_centered(draw, canvas_w, layout["text_top"], verb.upper(), verb_font, max_text_w)
    draw_centered(draw, canvas_w, y + VERB_DESC_GAP, desc.upper(), desc_font, max_text_w)

    # Device: centred, top at device_y, bleeding off the bottom edge.

    # Soft shadow under the device.
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [device_x, device_y + 30, device_x + device_w, device_y + device_h + 30],
        radius=corner, fill=(0, 0, 0, 150),
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(40)))

    # Body: near-black with a thin titanium rim.
    body = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    body_draw = ImageDraw.Draw(body)
    body_draw.rounded_rectangle(
        [device_x, device_y, device_x + device_w, device_y + device_h],
        radius=corner, fill=(58, 58, 64, 255),
    )
    body_draw.rounded_rectangle(
        [device_x + 5, device_y + 5, device_x + device_w - 5, device_y + device_h - 5],
        radius=corner - 5, fill=(10, 10, 12, 255),
    )
    canvas = Image.alpha_composite(canvas, body)

    # Screen with the capture, masked to the display's rounded corners.
    screen_x, screen_y = device_x + bezel, device_y + bezel
    screen = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    screen.paste(shot.resize((screen_w, screen_h), Image.LANCZOS), (screen_x, screen_y))
    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [screen_x, screen_y, screen_x + screen_w, screen_y + screen_h],
        radius=corner - bezel, fill=255,
    )
    screen.putalpha(mask)
    canvas = Image.alpha_composite(canvas, screen)

    canvas.convert("RGB").save(output_path, "PNG")
    print(f"✓ {output_path} ({canvas_w}×{canvas_h})")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--layout", choices=LAYOUTS, required=True)
    parser.add_argument("--style", choices=["theme", "flat"], default="theme")
    parser.add_argument("--bg", default=BRAND_BG, help="solid colour for --style flat")
    parser.add_argument("--verb", required=True)
    parser.add_argument("--desc", required=True)
    parser.add_argument("--screenshot", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    compose(args.layout, args.style, args.bg, args.verb, args.desc, args.screenshot, args.output)


if __name__ == "__main__":
    main()
