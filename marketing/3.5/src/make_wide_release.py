#!/usr/bin/env python3
"""Hyperia City wide release (Fri Oct 23 2026): set images, the HYPERIA promo's second run, and GOTINKED.

    /opt/homebrew/bin/python3.14 marketing/3.5/src/make_wide_release.py [images|reel|<file name> ...]

- HYPERIA is back: the yearly plan at $9.99 for the first year (normally $19.99), Fri Oct 23 – Sat Oct 31,
  new and lapsed subscribers.
- GOTINKED: an App Store offer code for creators. Three free months, then the yearly plan at $19.99,
  new and lapsed subscribers.

Writes to marketing/drafts/images/2026-10-23/ and marketing/drafts/reels/2026-10-23/. Prices are a frozen
snapshot from our pricing backend (Lorcast USD foil, daily 06:00 UTC rows, Sat Oct 17 → Fri Oct 23) so
the image matches its caption.

Reuses make_hyperia_images.py (brand, card sprites), make_week_2026_10_20.py (thumbnails) and
make_promo.py (price row, code pill, cover pair, promo carousel slides, covers reel).
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import ImageDraw

HERE = Path(__file__).resolve().parent


def _load(name, **overrides):
    """A sibling script's definitions, without running its main()."""
    source = (HERE / name).read_text().rsplit("\nmain()", 1)[0]
    scope = {"__file__": str(HERE / name), "__name__": name}
    exec(compile(source, name, "exec"), scope)
    scope.update(overrides)
    return scope


hyc = _load("make_hyperia_images.py")
week = _load("make_week_2026_10_20.py")
# The promo slides read ENDS at call time, so the second run only needs a new date.
promo = _load("make_promo.py", ENDS="ends Sat Oct 31")
covers = promo["covers"]

ROOT, brand, event_art, CARDS = hyc["ROOT"], hyc["brand"], hyc["event_art"], hyc["CARDS"]
finish, place, sprite, background = hyc["finish"], hyc["place"], hyc["sprite"], hyc["background"]
text_center, cta = hyc["text_center"], hyc["cta"]
HEAVY, DEMI, ITALIC = hyc["HEAVY"], hyc["DEMI"], hyc["ITALIC"]
WHITE, GOLD, SOFT = hyc["WHITE"], hyc["GOLD"], hyc["SOFT"]
font, text_layer = brand["font"], brand["text_layer"]
price_row, code_pill, cover_pair = promo["price_row"], promo["code_pill"], promo["cover_pair"]
thumb = week["thumb"]

OUT_IMAGES = ROOT / "marketing/drafts/images/2026-10-23"
OUT_REELS = ROOT / "marketing/drafts/reels/2026-10-23"
ENDS = "ends Sat Oct 31"
GOTINKED = "GOTINKED"
YEARLY = "$19.99"

# The five most valuable Enchanteds on Fri Oct 23: (collector number, Sat 17, Fri 23).
TOP_ENCHANTEDS = [(236, 1112.48, 403.76), (230, 451.99, 316.50), (229, 250.00, 258.49),
                  (226, 749.75, 198.92), (238, 490.00, 192.98)]
MEDIAN_ENCHANTED_CHANGE = "−67%"  # median of all 18 Enchanteds, same window


# ---------------------------------------------------------------------------
# Wide release
# ---------------------------------------------------------------------------


def ig_everywhere():
    """Type-led: the set hits every shelf today, over a fan of Enchanteds."""
    c = background(1080, 1350, event_art.INK["amber"], 1150)
    y = text_center(c, 60, "HYPERIA CITY", HEAVY, 132, WHITE, max_width=960)
    y = text_center(c, y + 4, "IS EVERYWHERE", HEAVY, 112, GOLD, max_width=960)
    text_center(c, y + 14, "wide release is today", ITALIC, 56, GOLD, max_width=960)
    fan = [238, 226, 236, 230, 229]  # Marie, Rapunzel, Ariel, Belle, Max Goof
    for i in sorted(range(len(fan)), key=lambda i: -abs(i - 2)):
        k = i - 2
        place(c, sprite(fan[i], 330, rotate=-k * 10), 540 + k * 160, 760 + k * k * 22)
    cta(c, 1250, "Scan your pulls · Free on iOS")
    return c


def x_everywhere():
    c = background(1600, 900, event_art.INK["amber"], 780)
    y = text_center(c, 50, "HYPERIA CITY IS EVERYWHERE", HEAVY, 104, WHITE, max_width=1460)
    text_center(c, y + 8, "wide release is today · scan your pulls in Ink Well Keeper", ITALIC, 46, GOLD, max_width=1460)
    fan = [238, 226, 236, 230, 229]
    for i in sorted(range(len(fan)), key=lambda i: -abs(i - 2)):
        k = i - 2
        place(c, sprite(fan[i], 250, rotate=-k * 9), 800 + k * 230, 600 + k * k * 20)
    return c


def ig_week_prices():
    """Number-led: the Enchanted median since launch Saturday, then today's top five."""
    c = background(1080, 1350, event_art.INK["sapphire"], 1330)
    y = text_center(c, 40, MEDIAN_ENCHANTED_CHANGE, HEAVY, 300, GOLD, max_width=900)
    y = text_center(c, y - 4, "ENCHANTED PRICES IN ONE WEEK", HEAVY, 62, WHITE, tracking=2, max_width=960)
    text_center(c, y + 8, "launch Saturday to wide release day", ITALIC, 46, SOFT, max_width=960)
    d = ImageDraw.Draw(text_layer(c))
    f_name, f_old, f_new = font(DEMI, 34), font(DEMI, 30), font(HEAVY, 52)
    top, step = 560, 124
    for i, (n, sat, fri) in enumerate(TOP_ENCHANTEDS):
        ry = top + i * step
        d.rounded_rectangle((90, ry - 8, 990, ry + 104), radius=26, fill=(255, 255, 255, 20))
        place(c, thumb(n, 70), 155, ry + 48)
        d.text((220, ry + 8), CARDS[n]["name"], font=f_name, fill=WHITE)
        d.text((220, ry + 54), f"Launch Sat ${sat:,.0f}", font=f_old, fill=SOFT)
        value = f"${fri:,.0f}"
        w = d.textlength(value, font=f_new)
        d.text((954 - w, ry + 20), value, font=f_new, fill=GOLD)
    text_center(c, top + 5 * step + 6, "Lorcast market, foil · Oct 17 to Oct 23", DEMI, 28, SOFT, max_width=960)
    cta(c, 1250, "Price history on every card · Free on iOS")
    return c


# ---------------------------------------------------------------------------
# HYPERIA, second run
# ---------------------------------------------------------------------------


def ig_promo_back(where="Link in bio"):
    c = background(1080, 1350, event_art.INK["amethyst"], 1180)
    y = text_center(c, 48, "HALF-PRICE PRO", HEAVY, 128, WHITE, max_width=980)
    text_center(c, y + 2, "is back through Halloween", ITALIC, 54, GOLD, max_width=960)
    cover_pair(c, 560, 300, 150)
    y = price_row(c, 790)
    y = text_center(c, y + 18, "your first year of Pro", ITALIC, 50, GOLD, max_width=960)
    code_pill(c, y + 34)
    cta(c, 1250, f"{where} · {ENDS}")
    return c


def story_promo_back():
    c = background(1080, 1920, event_art.INK["amethyst"], 1700)
    y = text_center(c, 230, "HALF-PRICE", HEAVY, 170, WHITE, max_width=960)
    y = text_center(c, y + 4, "PRO IS BACK", HEAVY, 150, GOLD, max_width=960)
    y = text_center(c, y + 10, "for Hyperia City wide release", ITALIC, 62, GOLD, max_width=960)
    y = price_row(c, y + 60, big=190, small=88)
    code_pill(c, y + 50)
    # Leave ~1250–1600 empty for the link sticker.
    text_center(c, 1640, ENDS, ITALIC, 56, GOLD, max_width=960)
    text_center(c, 1780, "INK WELL KEEPER", HEAVY, 44, SOFT, tracking=6, max_width=960)
    return c


def x_promo_back():
    c = background(1600, 900, event_art.INK["amethyst"], 760)
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
    y = line(y + 6, "is back through Halloween", ITALIC, 56, GOLD)
    f_big, f_small = font(HEAVY, 170), font(HEAVY, 80)
    price, was = promo["PRICE"], promo["WAS"]
    py = y + 50
    d.text((100, py), price, font=f_big, fill=GOLD)
    bx = 100 + d.textlength(price, font=f_big) + 34
    bottom = d.textbbox((0, 0), price, font=f_big)[3]
    s_top, s_bottom = d.textbbox((0, 0), was, font=f_small)[1::2]
    sy = py + bottom - s_bottom
    d.text((bx, sy), was, font=f_small, fill=SOFT)
    mid = sy + (s_top + s_bottom) / 2
    d.line((bx - 4, mid, bx + d.textlength(was, font=f_small) + 4, mid), fill=GOLD, width=7)
    y = line(py + bottom + 16, "your first year · code HYPERIA", DEMI, 46, WHITE)
    line(y + 14, f"Free on iOS · offer {ENDS}", ITALIC, 40, SOFT)
    holo = covers["shadowed"](covers["holofoil"](brand["binder_cover"](covers["COVER_COLORS"]["amethyst"], "classic", 330)))
    star = covers["shadowed"](covers["Starlight"](brand["binder_cover"](covers["COVER_COLORS"]["midnight"], "classic", 330)).frame(1.2))
    place(c, star.rotate(-7, resample=3, expand=True), 1330, 470)
    place(c, holo.rotate(7, resample=3, expand=True), 1080, 450)
    return c


# ---------------------------------------------------------------------------
# GOTINKED (creator code)
# ---------------------------------------------------------------------------


def gotinked_offer(c, top):
    """'3 months free', the code, and the renewal terms, stacked from `top`. Returns the y below it."""
    y = text_center(c, top, "3 MONTHS", HEAVY, 150, GOLD, max_width=960)
    y = text_center(c, y + 2, "OF PRO, FREE", HEAVY, 96, WHITE, max_width=960)
    y = code_pill(c, y + 40, label=f"CODE  {GOTINKED}")
    return text_center(c, y + 24, f"then {YEARLY}/year · cancel anytime", ITALIC, 44, SOFT, max_width=960)


def ig_gotinked():
    """The image that goes with a creator DM: the joke first, the offer second."""
    c = background(1080, 1350, event_art.INK["ruby"], 1200)
    y = text_center(c, 56, "YOU'VE JUST", HEAVY, 92, WHITE, max_width=960)
    y = text_center(c, y + 2, "GOT INKED", HEAVY, 168, GOLD, max_width=980)
    cover_pair(c, y + 200, 250, 130)
    gotinked_offer(c, y + 420)
    cta(c, 1250, "App Store › Redeem Gift Card or Code")
    return c


def story_gotinked():
    """Creator-shareable story: link sticker goes in the gap under the code."""
    c = background(1080, 1920, event_art.INK["ruby"], 1700)
    y = text_center(c, 200, "YOU'VE JUST", HEAVY, 110, WHITE, max_width=960)
    y = text_center(c, y + 4, "GOT INKED", HEAVY, 190, GOLD, max_width=980)
    cover_pair(c, y + 230, 270, 140)
    gotinked_offer(c, y + 470)
    # Leave ~1450–1640 empty for the link sticker.
    text_center(c, 1700, "INK WELL KEEPER", HEAVY, 44, SOFT, tracking=6, max_width=960)
    return c


def ig_gotinked_redeem():
    c = background(1080, 1350, event_art.INK["emerald"], 1200)
    y = text_center(c, 48, "HOW TO REDEEM", HEAVY, 112, WHITE, max_width=980)
    y = text_center(c, y + 2, f"code {GOTINKED} · about ten seconds", ITALIC, 50, GOLD, max_width=960)
    d = ImageDraw.Draw(text_layer(c))
    f_num, f_label, f_sub = font(HEAVY, 120), font(DEMI, 48), font(ITALIC, 38)
    steps = [
        ("Open the App Store", "tap your profile picture, top right"),
        ("Redeem Gift Card or Code", f"enter {GOTINKED}: 3 months free"),
        ("Open Ink Well Keeper", "Pro is on. Not yet? Close and reopen the app"),
    ]
    top = y + 70
    for i, (label, sub) in enumerate(steps):
        ry = top + i * 262
        d.rounded_rectangle((90, ry, 990, ry + 222), radius=36, fill=(255, 255, 255, 22))
        d.text((136, ry + 40), str(i + 1), font=f_num, fill=GOLD)
        d.text((260, ry + 54), label, font=f_label, fill=WHITE)
        d.text((260, ry + 120), sub, font=f_sub, fill=SOFT)
    text_center(c, top + 820, f"Then {YEARLY}/year. Cancel anytime before it renews.", DEMI, 34, SOFT, max_width=960)
    cta(c, 1250, "New and returning subscribers")
    return c


IMAGES = [
    ("ig-wr-01-everywhere.png", ig_everywhere),
    ("x-wr-everywhere-1600x900.png", x_everywhere),
    ("ig-wr-02-enchanted-week.png", ig_week_prices),
    ("ig-promo-back-01-half-price.png", ig_promo_back),
    ("ig-promo-back-02-whats-in-pro.png", promo["ig_whats_in_pro"]),
    ("ig-promo-back-03-how-to-redeem.png", promo["ig_how_to_redeem"]),
    ("tt-promo-back-01-half-price.png", lambda: ig_promo_back(promo["TIKTOK_CTA"])),
    ("tt-promo-back-03-how-to-redeem.png", lambda: promo["ig_how_to_redeem"](tiktok=True)),
    ("story-promo-back.png", story_promo_back),
    ("x-promo-back-1600x900.png", x_promo_back),
    ("dm-gotinked.png", ig_gotinked),
    ("dm-gotinked-how-to-redeem.png", ig_gotinked_redeem),
    ("story-gotinked.png", story_gotinked),
]


# ---------------------------------------------------------------------------
# Reel: the covers reel with a "back through Halloween" end card
# ---------------------------------------------------------------------------


def promo_back_end_scene(where):
    def end(c):
        y = text_center(c, 190, "HALF-PRICE", HEAVY, 160, WHITE, max_width=960)
        y = text_center(c, y + 4, "PRO IS BACK", HEAVY, 140, GOLD, max_width=960)
        text_center(c, y + 14, "through Halloween", ITALIC, 58, GOLD, max_width=960)
        y = price_row(c, 1330, big=180, small=84)
        y = code_pill(c, y + 40)
        text_center(c, y + 40, f"{where} · {ENDS}", ITALIC, 52, SOFT, max_width=960)
    pair = [(covers["holofoil"](brand["binder_cover"](covers["COVER_COLORS"]["amethyst"], "classic", 330)), 380, 920, 0),
            (covers["cover"]("midnight", 330, "starlight"), 700, 940, 1.6)]
    yield from covers["render_scene"](4.0, end, pair, "amethyst", 16)


def make_reel(where, out):
    W, H, FPS = covers["W"], covers["H"], covers["FPS"]
    with tempfile.TemporaryDirectory() as tmp:
        end = Path(tmp) / "end.mp4"
        ffmpeg = subprocess.Popen(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
             "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p", str(end)],
            stdin=subprocess.PIPE)
        for frame in promo_back_end_scene(where):
            ffmpeg.stdin.write(frame.tobytes())
        ffmpeg.stdin.close()
        ffmpeg.wait()
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(promo["COVERS_REEL"]), "-i", str(end), "-filter_complex",
             f"[0:v]trim=0:{promo['COVERS_REEL_BODY']},setpts=PTS-STARTPTS[a];[1:v]setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1[v]",
             "-map", "[v]", "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p",
             "-movflags", "+faststart", str(out)], check=True)
    print("wrote", out)


def main():
    OUT_IMAGES.mkdir(parents=True, exist_ok=True)
    OUT_REELS.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    for i, (name, make) in enumerate(IMAGES):
        if only and name not in only and "images" not in only:
            continue
        finish(make(), 2300 + i).convert("RGB").save(OUT_IMAGES / name, optimize=True)
        print("image", name)
    if not only or "images" in only:
        # The last-day story has no date on it, so the first run's works as-is.
        shutil.copy(ROOT / "marketing/drafts/images/2026-10-16/promo/story-promo-last-day.png",
                    OUT_IMAGES / "story-promo-last-day.png")
    if not only or "reel" in only:
        make_reel("link in bio", OUT_REELS / "reel-covers-promo-back.mp4")
        make_reel("search Ink Well Keeper", OUT_REELS / "reel-covers-promo-back-tiktok.mp4")


main()
