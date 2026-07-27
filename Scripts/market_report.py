#!/usr/bin/env python3
"""
Weekly Lorcana market report from the Inkwell Keeper pricing backend.

Samples the chase cards (Enchanted/Epic/Iconic/Legendary printings from the
bundled catalog), pulls each one's price history, and reports the biggest
movers over the window. Feeds the weekly marketing drafts — content no other
Lorcana account can produce, since it comes from our own price history.

Usage:
    python3 Scripts/market_report.py [--days 7] [--top 5] [--json]
"""

import argparse
import json
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "Inkwell Keeper" / "Data"
PRICING_API = "https://29kwvipys3.execute-api.us-east-2.amazonaws.com"
CHASE_RARITIES = {"Enchanted", "Epic", "Iconic", "Legendary"}


def chase_cards() -> list:
    """(uniqueId, name, setName) for every chase-rarity printing in the catalog."""
    cards = []
    for f in sorted(DATA_DIR.glob("*.json")):
        if f.stem in ("sets", "migration_map", "starter_decks", "official_card_ids"):
            continue
        doc = json.load(open(f, encoding="utf-8"))
        for c in doc.get("cards", []):
            if c.get("rarity") in CHASE_RARITIES and c.get("uniqueId"):
                cards.append((c["uniqueId"], c["name"], c.get("setName", "")))
    return cards


def fetch_history(uid: str, days: int):
    url = f"{PRICING_API}/prices/{uid}/history?days={days}"
    req = urllib.request.Request(url, headers={"User-Agent": "InkwellKeeper-MarketReport/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            points = json.loads(resp.read()).get("points", [])
    except Exception:
        return None
    # Market rows only (exclude lowest-listing rows), latest row per day
    market = [p for p in points if "low" not in p["marketplace"].lower() and p.get("price_usd")]
    if len(market) < 2:
        return None
    return market[0]["price_usd"], market[-1]["price_usd"]


def build_report(days: int, top: int) -> dict:
    cards = chase_cards()
    movers = []

    def check(entry):
        uid, name, set_name = entry
        result = fetch_history(uid, days)
        if not result:
            return None
        start, end = result
        if start <= 0 or end <= 0:
            return None
        change = end - start
        pct = change / start * 100
        return {
            "uniqueId": uid, "name": name, "set": set_name,
            "from": round(start, 2), "to": round(end, 2),
            "change": round(change, 2), "pct": round(pct, 1),
        }

    with ThreadPoolExecutor(max_workers=8) as pool:
        for row in pool.map(check, cards):
            if row and abs(row["change"]) >= 0.5:  # ignore noise
                movers.append(row)

    gainers = sorted(movers, key=lambda m: m["pct"], reverse=True)[:top]
    losers = sorted(movers, key=lambda m: m["pct"])[:top]
    return {"days": days, "sampled": len(cards), "gainers": gainers, "losers": losers}


def format_text(report: dict) -> str:
    lines = [f"Lorcana market movers — last {report['days']} days "
             f"({report['sampled']} chase cards tracked)", ""]
    lines.append("📈 Gainers:")
    for m in report["gainers"]:
        lines.append(f"  {m['name']} ({m['set']}): ${m['from']} → ${m['to']}  ({m['pct']:+.1f}%)")
    lines.append("")
    lines.append("📉 Losers:")
    for m in report["losers"]:
        lines.append(f"  {m['name']} ({m['set']}): ${m['from']} → ${m['to']}  ({m['pct']:+.1f}%)")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--top", type=int, default=5)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    report = build_report(args.days, args.top)
    print(json.dumps(report, indent=2) if args.json else format_text(report))
    sys.exit(0)


if __name__ == "__main__":
    main()
