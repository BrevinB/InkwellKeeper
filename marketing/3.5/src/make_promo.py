#!/usr/bin/env python3
"""Hyperia City weekend promo: half-price first year of Pro with offer code HYPERIA.

    python3 marketing/3.5/src/make_promo.py [images|reel|<file name> ...]

The offer is an App Store offer code on the yearly plan: $9.99 for the first year
(normally $19.99), redeemable Fri Oct 16 – Mon Oct 19 2026.

Writes to marketing/drafts/images/2026-10-16/promo/:
- ig-promo-01-half-price.png, ig-promo-02-whats-in-pro.png, ig-promo-03-how-to-redeem.png (1080×1350 carousel)
- story-promo-offer.png, story-promo-last-day.png (1080×1920, lower half left clear for the link sticker)
- x-promo-1600x900.png
- tt-promo-01-half-price.png, tt-promo-03-how-to-redeem.png (TikTok photo mode: no bio link, so they
  point to the App Store's Redeem Gift Card or Code instead)
and marketing/drafts/reels/2026-10-16/reel-covers-promo.mp4: the Pro covers reel with a promo end card
in place of its "Free on iOS" one, plus reel-covers-promo-tiktok.mp4 with a search CTA.

Reuses the brand helpers via make_hyperia_images.py (sparkles kept off text and covers) and the
Starlight/Holofoil renderers from make_covers_reel.py.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import ImageDraw

HERE = Path(__file__).resolve().parent


def _load(name):
    """A sibling script's definitions, without running its main()."""
    source = (HERE / name).read_text().rsplit("\nmain()", 1)[0]
    scope = {"__file__": str(HERE / name), "__name__": name}
    exec(compile(source, name, "exec"), scope)
    return scope


hyc = _load("make_hyperia_images.py")
covers = _load("make_covers_reel.py")

ROOT, brand, event_art = hyc["ROOT"], hyc["brand"], hyc["event_art"]
finish, background, text_center, cta = hyc["finish"], hyc["background"], hyc["text_center"], hyc["cta"]
HEAVY, DEMI, ITALIC = hyc["HEAVY"], hyc["DEMI"], hyc["ITALIC"]
WHITE, GOLD, SOFT = hyc["WHITE"], hyc["GOLD"], hyc["SOFT"]
font, text_layer = brand["font"], brand["text_layer"]
DARK = (21, 20, 33)

OUT_IMAGES = ROOT / "marketing/drafts/images/2026-10-16/promo"
COVERS_REEL = ROOT / "marketing/drafts/reels/2026-10-16/reel-covers-pro-finishes.mp4"
OUT_REEL = ROOT / "marketing/drafts/reels/2026-10-16/reel-covers-promo.mp4"
OUT_REEL_TIKTOK = ROOT / "marketing/drafts/reels/2026-10-16/reel-covers-promo-tiktok.mp4"
COVERS_REEL_BODY = 2.4 + 3.6 + 3.2 + 3.4  # scenes 1–4 of make_covers_reel.py; its end card is dropped

PRICE, WAS, CODE, ENDS = "$9.99", "$19.99", "HYPERIA", "ends Mon Oct 19"
BIO_CTA = "Link in bio"
TIKTOK_CTA = "Search Ink Well Keeper"

PRO = [
    ("Starlight & Holofoil binder covers", "twinkle and rainbow foil"),
    ("Unlimited binders & boxes", "free includes 3"),
    ("Set checklist binders", "every card in its pocket, master set too"),
    ("Scan straight into a binder", "pull, scan, filed"),
    ("Collection value history", "see what moved this week"),
    ("AI deck builder", "describe a deck, get one back"),
    ("Rules assistant", "answers with rule citations"),
    ("Trade calculator", "value both sides first"),
]


# ---------------------------------------------------------------------------
# Pieces
# ---------------------------------------------------------------------------


def price_row(c, y, big=210, small=96):
    """Struck-through regular price beside the promo price, centred. Returns the y below it."""
    d = ImageDraw.Draw(text_layer(c))
    f_big, f_small = font(HEAVY, big), font(HEAVY, small)
    w_big, w_small, gap = d.textlength(PRICE, font=f_big), d.textlength(WAS, font=f_small), big * .22
    x = (c.width - (w_small + gap + w_big)) / 2
    _, top, _, bottom = d.textbbox((0, 0), PRICE, font=f_big)
    _, s_top, _, s_bottom = d.textbbox((0, 0), WAS, font=f_small)
    small_y = y + bottom - s_bottom  # share a baseline with the big price
    d.text((x, small_y), WAS, font=f_small, fill=SOFT)
    mid = small_y + (s_top + s_bottom) / 2
    d.line((x - 6, mid, x + w_small + 6, mid), fill=GOLD, width=max(6, small // 12))
    d.text((x + w_small + gap, y), PRICE, font=f_big, fill=GOLD)
    return y + bottom


def code_pill(c, y, size=58, label=f"CODE  {CODE}"):
    """Outlined gold pill with the code, so it reads as something to type."""
    d = ImageDraw.Draw(text_layer(c))
    f = font(HEAVY, size)
    tracking = size * .08
    w = d.textlength(label, font=f) + tracking * (len(label) - 1)
    pad_x, h = size * .9, size * 1.7
    box = ((c.width - w) / 2 - pad_x, y, (c.width + w) / 2 + pad_x, y + h)
    d.rounded_rectangle(box, radius=h / 2, fill=DARK + (235,), outline=GOLD, width=5)
    x = (c.width - w) / 2
    _, top, _, bottom = d.textbbox((0, 0), label, font=f)
    ty = y + (h - (bottom + top)) / 2
    for ch in label:
        d.text((x, ty), ch, font=f, fill=WHITE)
        x += d.textlength(ch, font=f) + tracking
    return y + h


def cover_pair(c, cy, width, spread):
    """A Holofoil and a Starlight cover, leaning in, as the visual for the offer."""
    holo = covers["shadowed"](covers["holofoil"](brand["binder_cover"](covers["COVER_COLORS"]["amethyst"], "classic", width)))
    star = covers["shadowed"](covers["Starlight"](brand["binder_cover"](covers["COVER_COLORS"]["midnight"], "classic", width)).frame(1.2))
    hyc["place"](c, star.rotate(-7, resample=3, expand=True), c.width / 2 + spread, cy + 20)
    hyc["place"](c, holo.rotate(7, resample=3, expand=True), c.width / 2 - spread, cy)


# ---------------------------------------------------------------------------
# Images
# ---------------------------------------------------------------------------


def ig_half_price(where=BIO_CTA):
    c = background(1080, 1350, event_art.INK["amethyst"], 1180)
    y = text_center(c, 48, "HALF-PRICE PRO", HEAVY, 128, WHITE, max_width=980)
    text_center(c, y + 2, "for Hyperia City weekend", ITALIC, 54, GOLD, max_width=960)
    cover_pair(c, 560, 300, 150)
    y = price_row(c, 790)
    y = text_center(c, y + 18, "your first year of Pro", ITALIC, 50, GOLD, max_width=960)
    code_pill(c, y + 34)
    cta(c, 1250, f"{where} · {ENDS}")
    return c


def ig_whats_in_pro():
    c = background(1080, 1350, event_art.INK["sapphire"], 1220)
    y = text_center(c, 48, "WHAT'S IN PRO", HEAVY, 112, WHITE, max_width=980)
    y = text_center(c, y + 2, f"{PRICE} for your first year with code {CODE}", ITALIC, 44, GOLD, max_width=980)
    d = ImageDraw.Draw(text_layer(c))
    f_label, f_sub = font(DEMI, 40), font(ITALIC, 32)
    top = y + 40
    for i, (label, sub) in enumerate(PRO):
        ry = top + i * 118
        d.rounded_rectangle((90, ry, 990, ry + 100), radius=28, fill=(255, 255, 255, 22))
        d.text((130, ry + 13), label, font=f_label, fill=WHITE)
        d.text((130, ry + 58), sub, font=f_sub, fill=GOLD)
    cta(c, 1250, f"Link in bio · {ENDS}")
    return c


def ig_how_to_redeem(tiktok=False):
    c = background(1080, 1350, event_art.INK["emerald"], 1200)
    y = text_center(c, 48, "HOW TO REDEEM", HEAVY, 112, WHITE, max_width=980)
    y = text_center(c, y + 2, "takes about ten seconds", ITALIC, 50, GOLD, max_width=960)
    d = ImageDraw.Draw(text_layer(c))
    f_num, f_label, f_sub = font(HEAVY, 120), font(DEMI, 48), font(ITALIC, 38)
    steps = [
        ("Tap the link in our bio", "it opens the App Store with the code filled in"),
    ] if not tiktok else [
        ("Open the App Store", "tap your profile picture, top right"),
    ]
    steps += [
        ("Redeem Gift Card or Code", f"enter {CODE}: {PRICE} first year, then {WAS}/yr") if tiktok
        else (f"Redeem code {CODE}", f"{PRICE} for your first year, then {WAS}/year"),
        ("Open Ink Well Keeper", "Pro is on. Not yet? Close and reopen the app"),
    ]
    top = y + 70
    for i, (label, sub) in enumerate(steps):
        ry = top + i * 262
        d.rounded_rectangle((90, ry, 990, ry + 222), radius=36, fill=(255, 255, 255, 22))
        d.text((136, ry + 40), str(i + 1), font=f_num, fill=GOLD)
        d.text((260, ry + 54), label, font=f_label, fill=WHITE)
        d.text((260, ry + 120), sub, font=f_sub, fill=SOFT)
    text_center(c, top + 820, "Works for new and returning subscribers", DEMI, 34, SOFT, max_width=960)
    cta(c, 1250, f"Offer {ENDS}")
    return c


def story_offer():
    c = background(1080, 1920, event_art.INK["amethyst"], 1700)
    y = text_center(c, 230, "HALF-PRICE", HEAVY, 170, WHITE, max_width=960)
    y = text_center(c, y + 4, "PRO", HEAVY, 190, GOLD, max_width=960)
    y = text_center(c, y + 10, "Hyperia City weekend only", ITALIC, 62, GOLD, max_width=960)
    y = price_row(c, y + 60, big=190, small=88)
    y = code_pill(c, y + 50)
    # Leave ~1250–1600 empty for the link sticker.
    text_center(c, 1640, ENDS, ITALIC, 56, GOLD, max_width=960)
    text_center(c, 1780, "INK WELL KEEPER", HEAVY, 44, SOFT, tracking=6, max_width=960)
    return c


def story_last_day():
    c = background(1080, 1920, event_art.INK["ruby"], 1700)
    y = text_center(c, 260, "LAST DAY", HEAVY, 200, GOLD, max_width=960)
    y = text_center(c, y + 10, "half-price Pro ends tonight", ITALIC, 66, WHITE, max_width=960)
    y = price_row(c, y + 70, big=190, small=88)
    code_pill(c, y + 50)
    text_center(c, 1640, "tap the link above", ITALIC, 56, GOLD, max_width=960)
    text_center(c, 1780, "INK WELL KEEPER", HEAVY, 44, SOFT, tracking=6, max_width=960)
    return c


def x_promo():
    c = background(1600, 900, event_art.INK["amethyst"], 760)
    # Text on the left, covers on the right.
    left = 820
    d = ImageDraw.Draw(text_layer(c))

    def line(y, text, spec, size, fill):
        f = font(spec, size)
        while d.textlength(text, font=f) > left - 120 and size > 20:
            size -= 4
            f = font(spec, size)
        d.text((100, y), text, font=f, fill=fill)
        return y + d.textbbox((0, 0), text, font=f)[3]

    y = line(90, "HALF-PRICE PRO", HEAVY, 120, WHITE)
    y = line(y + 6, "for Hyperia City weekend", ITALIC, 56, GOLD)
    f_big, f_small = font(HEAVY, 170), font(HEAVY, 80)
    py = y + 50
    d.text((100, py), PRICE, font=f_big, fill=GOLD)
    bx = 100 + d.textlength(PRICE, font=f_big) + 34
    bottom = d.textbbox((0, 0), PRICE, font=f_big)[3]
    s_top, s_bottom = d.textbbox((0, 0), WAS, font=f_small)[1::2]
    sy = py + bottom - s_bottom
    d.text((bx, sy), WAS, font=f_small, fill=SOFT)
    mid = sy + (s_top + s_bottom) / 2
    d.line((bx - 4, mid, bx + d.textlength(WAS, font=f_small) + 4, mid), fill=GOLD, width=7)
    y = line(py + bottom + 16, "your first year · code HYPERIA", DEMI, 46, WHITE)
    line(y + 14, f"Free on iOS · offer {ENDS}", ITALIC, 40, SOFT)
    holo = covers["shadowed"](covers["holofoil"](brand["binder_cover"](covers["COVER_COLORS"]["amethyst"], "classic", 330)))
    star = covers["shadowed"](covers["Starlight"](brand["binder_cover"](covers["COVER_COLORS"]["midnight"], "classic", 330)).frame(1.2))
    hyc["place"](c, star.rotate(-7, resample=3, expand=True), 1330, 470)
    hyc["place"](c, holo.rotate(7, resample=3, expand=True), 1080, 450)
    return c


IMAGES = [
    ("ig-promo-01-half-price.png", ig_half_price),
    ("ig-promo-02-whats-in-pro.png", ig_whats_in_pro),
    ("ig-promo-03-how-to-redeem.png", ig_how_to_redeem),
    ("story-promo-offer.png", story_offer),
    ("story-promo-last-day.png", story_last_day),
    ("x-promo-1600x900.png", x_promo),
    ("tt-promo-01-half-price.png", lambda: ig_half_price(TIKTOK_CTA)),
    ("tt-promo-03-how-to-redeem.png", lambda: ig_how_to_redeem(tiktok=True)),
]


# ---------------------------------------------------------------------------
# Reel: the covers reel's first four scenes + a promo end card
# ---------------------------------------------------------------------------


def promo_end_scene(where="link in bio"):
    def end(c):
        y = text_center(c, 190, "HALF-PRICE", HEAVY, 160, WHITE, max_width=960)
        y = text_center(c, y + 4, "PRO", HEAVY, 180, GOLD, max_width=960)
        text_center(c, y + 14, "Hyperia City weekend only", ITALIC, 58, GOLD, max_width=960)
        y = price_row(c, 1330, big=180, small=84)
        y = code_pill(c, y + 40)
        text_center(c, y + 40, f"{where} · {ENDS}", ITALIC, 52, SOFT, max_width=960)
    pair = [(covers["holofoil"](brand["binder_cover"](covers["COVER_COLORS"]["amethyst"], "classic", 330)), 380, 920, 0),
            (covers["cover"]("midnight", 330, "starlight"), 700, 940, 1.6)]
    yield from covers["render_scene"](4.0, end, pair, "amethyst", 16)


def make_reel(where="link in bio", out=OUT_REEL):
    W, H, FPS = covers["W"], covers["H"], covers["FPS"]
    with tempfile.TemporaryDirectory() as tmp:
        end = Path(tmp) / "end.mp4"
        ffmpeg = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
             "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p", str(end)],
            stdin=subprocess.PIPE)
        for frame in promo_end_scene(where):
            ffmpeg.stdin.write(frame.tobytes())
        ffmpeg.stdin.close()
        ffmpeg.wait()
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(COVERS_REEL), "-i", str(end), "-filter_complex",
             f"[0:v]trim=0:{COVERS_REEL_BODY},setpts=PTS-STARTPTS[a];[1:v]setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1[v]",
             "-map", "[v]", "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p",
             "-movflags", "+faststart", str(out)], check=True)
    print("wrote", out)


def main():
    OUT_IMAGES.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    for i, (name, make) in enumerate(IMAGES):
        if only and name not in only and "images" not in only:
            continue
        finish(make(), 1700 + i).convert("RGB").save(OUT_IMAGES / name, optimize=True)
        print("image", name)
    if not only or "reel" in only:
        make_reel()
    if not only or "reel" in only or "reel-tiktok" in only:
        make_reel("search Ink Well Keeper", OUT_REEL_TIKTOK)


main()
