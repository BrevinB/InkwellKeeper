# Weekly Marketing Drafts — July 28, 2026

**Primary pillar:** Feature spotlight (3.1 import update, led by the official-app import). Last week the market report led both X and Reddit, and the rotation forbids it leading twice in a row. Feature spotlights haven't led yet, and 3.1.0 shipped this week (git: `Release 3.1.0`) — the timeliest possible spotlight window.
**Pillars used:** Feature spotlight (X, TikTok 1, IG) · Collector tips (Reddit, TikTok 2) · Market report (secondary: one tweet in the X thread, one line on Reddit).

> ⚠️ **Eyeball before posting:** four of five "gainers" this week look like thin-market blips, not demand — Stitch - Experiment 626 (+609%) and Mickey - Brave Little Prince (+576%) were flagged as suspicious *last week too* and are still printing absurd swings; Mickey - Inspirational Warrior (+460%) and Kida (+355%, sub-$2 card) fit the same pattern. The credible story is the **losers**: the Whispers dip continuing (Sudden Scare $19.16 → $13.11, second straight down week) and Jessie - Lively Cowgirl easing $314 → $268. Scrooge McDuck - Resourceful Miser is holding last week's gain (~$10), which makes it the one believable riser. Spot-check anything against TCGplayer before posting.
>
> ✅ **Also verify before posting:** confirm 3.1.0 is actually live on the App Store (it was in review last week; the release commit landed this week). Every draft below assumes it's live.

---

## X / Twitter — 3.1 feature spotlight thread

**Tweet 1 (hook):**
Ink Well Keeper 3.1 is live, and it does something no other Lorcana app can:

Import your collection straight from the official Disney Lorcana app. Paste your backup link → your whole collection appears. That's it.

The import update 🧵

**Tweet 2:**
Also new in 3.1:

📈 Price history charts on every card
💰 Market + TCGplayer Low, with true foil prices
🔍 Filter any set by ink, rarity, variant, ownership, and price range
⚡ Dreamborn imports now take seconds, not minutes
✨ Real Lorcana symbols in card text — no more {E} codes

**Tweet 3 (market secondary):**
Speaking of price history — this week's chart worth watching: Whispers in the Well chase cards are still dipping. Sudden Scare is down to $13.11 (from $19+ two weeks ago). Second straight down week. Buyers' window.

**Tweet 4 (close):**
Free on iOS. Scan your cards, import from anywhere, watch what your collection is worth:
https://apps.apple.com/us/app/ink-well-keeper/id6754206379

Built by one person, on your feedback. Tell me what 3.2 should be.

*(Attach: screen recording of the official-app import, or a screenshot of the new set filters.)*

---

## Reddit r/Lorcana — collector tip post (value-first)

**Title:** PSA: your collection data is portable — how to move it between trackers (and why you should export it either way)

**Body:**
After helping a bunch of people migrate collections this month, a few things I wish more collectors knew:

**1. The official Disney Lorcana app has a backup link.** Buried in its settings is a collection backup you can copy as a link. That link *is* your collection data — keep a copy somewhere even if you never switch apps. Apps get sunset; your pull history shouldn't.

**2. Dreamborn and Collectr both export cleanly.** Dreamborn's CSV and Collectr's export are well-formed and most trackers can read them. If you've got years of collection history in either, export it once in a while. It costs nothing.

**3. Watch out for foil vs normal when migrating.** Foils and normals are different printings with genuinely different prices, and some export formats mark foils in non-obvious ways (a suffix on the card ID, a separate column). After any import, spot-check a few foils you know you own — it's the #1 thing that goes wrong.

**4. Enchanted / Epic / Iconic are where matching breaks.** Chase-rarity variants share names with base cards, so name-only matching mislabels them. Set + card number is the reliable key if you're ever fixing a CSV by hand.

One market note while I'm here: Whispers in the Well chase cards have now dipped two weeks running (Sudden Scare $19 → $13). If one's been on your wishlist, it's the softest it's been.

(I build Ink Well Keeper, a free iOS tracker — 3.1 just shipped and imports from all of the above, including the official app's backup link. Happy to answer migration questions either way, whatever app you use.)

---

## TikTok — script outlines

### Script 1: "Import your whole Lorcana collection in 10 seconds" (~30s, feature spotlight)
- **Hook (0–3s):** "You logged your entire collection in the official Lorcana app. Getting it out takes ten seconds."
- **Beat 1 (3–12s):** Screen-record the official app: open settings, copy the collection backup link. "The official app gives you a backup link. Copy it."
- **Beat 2 (12–22s):** Switch to Ink Well Keeper, paste, watch the collection flood in with the counter climbing. "Paste it here. Every card, every foil. No other app can read this."
- **CTA (22–30s):** "Free, just shipped in 3.1 — link in bio. Your collection, plus prices, scanning, and set tracking on top."

### Script 2: "When a chase card dips, here's what I actually do" (~35s, collector tip)
- **Hook (0–4s):** "Whispers in the Well chase cards have dropped two weeks in a row. Here's how to not miss the bottom."
- **Beat 1 (4–14s):** Show Sudden Scare's price history chart falling. "Sudden Scare: over $19 two weeks ago, $13 today. Down 30%. This is what price discovery after a set's hype window looks like."
- **Beat 2 (14–26s):** "The move: wishlist the cards you actually want, then check the chart weekly instead of impulse-buying at peak. Falling knife or floor? The trend line tells you more than one price ever will."
- **CTA (26–35s):** "I track every card's price daily in the free app I built — wishlist plus price history, link in bio."

---

## Instagram / Threads — caption

**Attach:** card-flex share card of a chase card showing its price history chart — or a before/after screenshot pair of the official-app import (empty collection → full collection).

**Caption:**
3.1 is out. 🎉 This one's called the import update for a reason — paste your backup link from the official Disney Lorcana app and your whole collection walks right in. Collectr and Dreamborn imports too (now seconds, not minutes).

Plus: price history charts on every card, real foil prices, and set filters that finally let you find anything.

Built by one person, shaped by your bug reports. Keep them coming.

Free on iOS · link in bio
#Lorcana #DisneyLorcana #LorcanaTCG #CardCollecting #DisneyCards

---

*Prices from `Scripts/market_report.py` (7-day window, 483 chase cards) at generation time; feature claims from `marketing/3.1/RELEASE_NOTES.md` and git history. Nothing publishes automatically — Brevin reviews and posts.*
