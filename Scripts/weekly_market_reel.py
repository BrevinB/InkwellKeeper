#!/usr/bin/env python3
"""
Generate the weekly Instagram market reel (1080x1920 mp4, silent).

Picks the two most credible movers from the pricing backend (blip-filtered per
the playbook), animates their price history in the brand style, and renders
frame-by-frame through headless Chrome before assembling with ffmpeg. Called
by Scripts/weekly_drafts.sh on Mondays; safe to run standalone.

    python3 Scripts/weekly_market_reel.py --out marketing/drafts/reels/2026-08-10/reel-market.mp4

Requires: Google Chrome, ffmpeg. Renders sequentially WITHOUT --user-data-dir
(a custom profile dir hangs headless screenshots on this machine).
"""

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PRICING_API = "https://29kwvipys3.execute-api.us-east-2.amazonaws.com"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
GOLD = "#FFD700"
GRAD = "linear-gradient(135deg,#0D1A33 0%,#1A0D26 55%,#0D1A33 100%)"
SERIES_COLORS = ["#3987e5", "#d95926"]  # validated against brand gradient
FPS_RENDER = 12
FPS_OUT = 30
DURATION = 13.5

# Credibility window per the playbook: big % swings are usually thin-market
# blips or data corrections, not demand.
MIN_ABS_PCT, MAX_ABS_PCT, MIN_PRICE = 8.0, 60.0, 3.0


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def report(days):
    out = subprocess.run(
        [sys.executable, str(REPO / "Scripts/market_report.py"),
         "--days", str(days), "--top", "10", "--json"],
        capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def daily_history(uid, days):
    req = urllib.request.Request(
        f"{PRICING_API}/prices/{uid}/history?days={days}",
        headers={"User-Agent": "InkwellKeeper-MarketReel/1.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        points = json.loads(resp.read()).get("points", [])
    market = [p for p in points
              if "low" not in p["marketplace"].lower() and p.get("price_usd")]
    daily = {}
    for p in market:
        daily[p["recorded_at"][:10]] = p["price_usd"]
    return sorted(daily.items())


def pick_movers(rep):
    pool = rep["gainers"] + rep["losers"]
    credible, seen = [], set()
    for m in sorted(pool, key=lambda m: abs(m["pct"]), reverse=True):
        if (MIN_ABS_PCT <= abs(m["pct"]) <= MAX_ABS_PCT
                and m["to"] >= MIN_PRICE and m["uniqueId"] not in seen):
            seen.add(m["uniqueId"])
            credible.append(m)
    if len(credible) < 2:
        return None
    # Both lines share one dollar axis, so a $200 card next to a $10 card
    # flattens the cheap one into a flat line. Prefer the strongest pair
    # whose prices are within ~6x of each other.
    for i, a in enumerate(credible):
        for b in credible[i + 1:]:
            hi, lo = max(a["to"], b["to"]), min(a["to"], b["to"])
            if hi / lo <= 6:
                return [a, b]
    return credible[:2]


def rnd(seed, lo, hi):
    h = int(hashlib.md5(str(seed).encode()).hexdigest()[:8], 16) / 0xFFFFFFFF
    return lo + h * (hi - lo)


def build_html(movers, histories):
    PL, PR, PT, PB = 100, 800, 140, 560
    allv = [v for h in histories for _, v in h]
    ymin, ymax = min(allv), max(allv)
    pad = max((ymax - ymin) * 0.18, 1)
    ymin, ymax = ymin - pad, ymax + pad

    def px(i, n):
        return PL + i * (PR - PL) / (n - 1)

    def py(v):
        return PB - (v - ymin) * (PB - PT) / (ymax - ymin)

    grid = []
    raw = max((ymax - ymin) / 3, 0.5)
    mag = 10 ** len(str(int(raw))) / 10
    step = min((s for s in (1 * mag, 2 * mag, 5 * mag, 10 * mag) if s >= raw),
               default=raw)
    step = max(int(step), 1)
    g = (int(max(ymin, 0) // step) + 1) * step
    while g < ymax:
        grid.append(
            f'<text x="{PL-14}" y="{py(g)+6:.0f}" text-anchor="end" fill="#8f92ab" font-size="20">${g}</text>'
            f'<line x1="{PL}" y1="{py(g):.0f}" x2="{PR}" y2="{py(g):.0f}" stroke="rgba(255,255,255,0.08)"/>')
        g += step

    lines, labels, jsvals = [], [], []
    label_ys = []
    for k, (m, h) in enumerate(zip(movers, histories)):
        n = len(h)
        pts = " ".join(f"{px(i, n):.1f},{py(v):.1f}" for i, (_, v) in enumerate(h))
        lines.append(
            f'<polyline id="ln{k}" points="{pts}" fill="none" stroke="{SERIES_COLORS[k]}"'
            f' stroke-width="6" stroke-linejoin="round" stroke-linecap="round"/>')
        ly = py(h[-1][1])
        for prev in label_ys:  # avoid overlapping end labels
            if abs(ly - prev) < 96:
                ly = prev + 96 if ly >= prev else prev - 96
        label_ys.append(ly)
        labels.append(
            f'<div class="price" id="pr{k}" style="left:815px;top:{ly-28:.0f}px"></div>'
            f'<div class="pchip" id="ch{k}" style="left:815px;top:{ly+20:.0f}px">{m["pct"]:+.0f}%</div>')
        jsvals.append(f"[{h[0][1]:.2f},{h[-1][1]:.2f}]")

    short = [m["name"].split(" - ")[0] for m in movers]
    legend = "".join(
        f'<i style="background:{SERIES_COLORS[k]}"></i>{short[k]}' for k in range(2))
    d0, d1 = histories[0][0][0], histories[0][-1][0]
    fmt = lambda d: datetime.strptime(d, "%Y-%m-%d").strftime("%b %-d")
    spark = "".join(
        f'<circle cx="{rnd(("r2", i, "x"), 30, 1050):.0f}" cy="{rnd(("r2", i, "y"), 30, 1890):.0f}"'
        f' r="{rnd(("r2", i, "r"), 1.5, 3.5):.1f}" fill="{GOLD}" opacity="{rnd(("r2", i, "o"), 0.08, 0.25):.2f}"/>'
        for i in range(30))

    return f'''<meta charset="utf-8"><style>
html,body{{margin:0;padding:0}} body{{width:1080px;height:1920px;background:{GRAD};overflow:hidden;position:relative;font-family:"Avenir Next",-apple-system,sans-serif}}
.glowp{{position:absolute;left:-240px;bottom:-300px;width:900px;height:900px;border-radius:50%;background:radial-gradient(circle,rgba(128,51,204,0.16),transparent 65%)}}
.disp{{font-family:"Avenir Next Condensed",sans-serif;font-weight:800;color:#fff;text-transform:uppercase;line-height:0.95}}
.magic{{font-family:Baskerville,Georgia,serif;font-style:italic;font-weight:600;color:{GOLD}}}
#s1{{position:absolute;left:0;right:0;top:640px;text-align:center}}
#s1 .l1{{font-size:170px}} #s1 .l2{{font-size:150px;margin-top:6px}} #s1 .l3{{color:#cfd2e4;font-size:34px;margin-top:36px}}
#s2h{{position:absolute;left:0;right:0;top:390px;text-align:center;color:#cfd2e4;font-size:38px}}
#panel{{position:absolute;left:90px;top:560px;width:900px;height:760px;background:rgba(13,20,45,0.8);border:2px solid rgba(255,215,0,0.4);border-radius:30px}}
#panel .pt{{position:absolute;left:40px;top:34px;color:#fff;font-size:30px;font-weight:700}}
#panel .lg{{position:absolute;right:40px;top:38px;color:#cfd2e4;font-size:20px}}
#panel .lg i{{display:inline-block;width:13px;height:13px;border-radius:7px;margin:0 8px 0 24px;vertical-align:-1px;font-style:normal}}
.price{{position:absolute;color:#fff;font-weight:800;font-size:44px;font-variant-numeric:tabular-nums}}
.pchip{{position:absolute;color:{GOLD};font-weight:700;font-size:30px}}
#s3{{position:absolute;left:0;right:0;top:700px;text-align:center}}
#s3 .a{{font-size:130px}} #s3 .b{{font-size:130px;color:{GOLD}}} #s3 .c{{font-size:56px;margin-top:40px}}
#s4{{position:absolute;left:0;right:0;top:780px;text-align:center}}
#s4 .w{{color:{GOLD};font-size:76px;font-weight:700}}
#s4 .t{{color:#cfd2e4;font-size:40px;margin-top:24px}}
</style><body>
<div class="glowp"></div>
<svg width="1080" height="1920" style="position:absolute;top:0;left:0">{spark}
<defs><linearGradient id="g1" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" stop-color="#2F7FD4"/><stop offset="100%" stop-color="#8033CC"/></linearGradient></defs>
<path id="rib" d="M -100 1560 C 300 1660, 700 1440, 1180 1540" fill="none" stroke="url(#g1)" stroke-width="80" stroke-linecap="round" opacity="0.6"/>
</svg>
<div id="s1"><div class="disp l1">The market</div><div class="magic l2">moved.</div><div class="l3">Lorcana chase cards · week of {fmt(d1)}</div></div>
<div id="s2h">Biggest credible movers · market price</div>
<div id="panel">
  <div class="pt">{fmt(d0)} → {fmt(d1)}</div>
  <div class="lg">{legend}</div>
  <svg id="chart" width="900" height="760">{''.join(grid)}{''.join(lines)}</svg>
  {''.join(labels)}
</div>
<div id="s3"><div class="disp a">Every card.</div><div class="disp b">Tracked daily.</div><div class="magic c">in the app I built.</div></div>
<div id="s4"><svg width="90" height="90" viewBox="0 0 20 20"><path d="M10 1 L12 8 L19 10 L12 12 L10 19 L8 12 L1 10 L8 8 Z" fill="{GOLD}"/></svg>
<div class="w">Ink Well Keeper</div><div class="t">Free on iOS · link in bio</div></div>
<script>
const T = parseFloat(location.hash.slice(1)) || 0;
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
const eo=x=>1-Math.pow(1-clamp(x,0,1),3);
function seg(t,a,b){{return eo((t-a)/(b-a));}}
const $=id=>document.getElementById(id);
function set(el,o,ty,s){{el.style.opacity=o;el.style.transform=`translateY(${{ty}}px) scale(${{s??1}})`;}}
const V=[{','.join(jsvals)}];
$('rib').setAttribute('transform',`translate(0,${{Math.sin(T*0.8)*12}})`);
{{const i1=seg(T,0.05,0.65),i2=seg(T,0.55,1.15),i3=seg(T,1.1,1.6),out=1-seg(T,2.2,2.6);
set(document.querySelector('#s1 .l1'),Math.min(i1,out),(1-i1)*60,1);
set(document.querySelector('#s1 .l2'),Math.min(i2,out),0,0.7+0.3*i2);
set(document.querySelector('#s1 .l3'),Math.min(i3,out),(1-i3)*20,1);
$('s1').style.display=T<2.7?'block':'none';}}
{{const pin=seg(T,2.5,3.0),pout=1-seg(T,8.8,9.2);
const op=Math.min(pin,pout);
$('panel').style.opacity=op; $('s2h').style.opacity=op;
$('panel').style.transform=`scale(${{0.92+0.08*pin}})`;
const p=seg(T,3.1,6.7);
for(const k of [0,1]){{
  const ln=$('ln'+k),L=ln.getTotalLength();
  ln.style.strokeDasharray=L; ln.style.strokeDashoffset=L*(1-p);
  const v=V[k][0]+(V[k][1]-V[k][0])*p;
  $('pr'+k).textContent='$'+v.toFixed(0);
  $('pr'+k).style.opacity=op*seg(T,3.2,3.5);
  const cp=seg(T,6.8,7.2)*op;
  set($('ch'+k),cp,(1-cp)*14);
}}}}
{{const a=seg(T,9.3,9.8),b=seg(T,9.9,10.4),c=seg(T,10.5,11.0),out=1-seg(T,11.7,12.1);
set(document.querySelector('#s3 .a'),Math.min(a,out),(1-a)*50);
set(document.querySelector('#s3 .b'),Math.min(b,out),(1-b)*50);
set(document.querySelector('#s3 .c'),Math.min(c,out),(1-c)*24);
$('s3').style.display=(T>9.2&&T<12.2)?'block':'none';}}
{{const i=seg(T,12.2,12.8);
$('s4').style.opacity=i; $('s4').style.transform=`scale(${{0.94+0.06*i}})`;}}
</script></body>'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", required=True)
    ap.add_argument("--days", type=int, default=9)
    args = ap.parse_args()

    if not Path(CHROME).exists() or not shutil.which("ffmpeg"):
        sys.exit("chrome or ffmpeg missing")

    rep = report(args.days)
    movers = pick_movers(rep)
    if not movers:
        sys.exit("no credible movers this week — skipping reel")
    histories = [daily_history(m["uniqueId"], args.days) for m in movers]
    if any(len(h) < 4 for h in histories):
        sys.exit("not enough history points — skipping reel")

    work = Path(tempfile.mkdtemp(prefix="market-reel-"))
    page = work / "reel.html"
    page.write_text(build_html(movers, histories))
    frames = work / "frames"
    frames.mkdir()

    total = int(DURATION * FPS_RENDER)
    for n in range(total):
        run([CHROME, "--headless", "--disable-gpu",
             f"--screenshot={frames}/f_{n:04d}.png",
             "--window-size=1080,1920", "--hide-scrollbars",
             f"file://{page}#{n / FPS_RENDER}"],
            capture_output=True)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    run(["ffmpeg", "-y", "-v", "error", "-framerate", str(FPS_RENDER),
         "-i", f"{frames}/f_%04d.png",
         "-vf", f"framerate=fps={FPS_OUT}",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-an", str(out)])
    shutil.rmtree(work)
    print(f"reel written: {out} ({movers[0]['name']} {movers[0]['pct']:+.0f}%, "
          f"{movers[1]['name']} {movers[1]['pct']:+.0f}%)")


if __name__ == "__main__":
    main()
