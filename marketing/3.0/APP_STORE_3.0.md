# Ink Well Keeper 3.0 — App Store Connect copy

Paste-ready metadata for the 3.0 submission. Items marked ⚠️ iCloud are conditional:
keep them only if sync is verified on two devices before submission.

---

## What's New (release notes)

```
Version 3.0 — our biggest update yet, ready for Attack of the Vine!

🌿 NEW SET: ATTACK OF THE VINE
All 242 cards from Set 13 are here on day one. Scan them, track them, price them.

📸 SHARE YOUR PULLS
Flex on your friends with gorgeous share cards! Generate branded images for your
booster hauls, single-card pulls, decks, collection milestones, and a full
collection recap — each with a QR code that opens the app.

⚡ FASTER SCANNING
The scanner has been redesigned. Batch-scan a whole stack of cards, review the
results, and add them all in one go.

🃏 DECKS, REDESIGNED
A rebuilt deck tab, deck sharing via QR code or link, and smarter validation for
Core, Infinity, and Casual formats.

🤖 AI TOOLS (PRO)
Let the AI Deck Builder craft a legal 60-card deck around your idea, and ask the
Rules Assistant about tricky card interactions — with your card in context.

📊 ALL-NEW STATS
Rarity breakdown, ink colors, cost curve, your top 10 most valuable cards, and
value by set — all in beautiful new charts.

☁️ iCLOUD SYNC (⚠️ include only if verified)
Your collection now syncs securely across your iPhone and iPad.

Plus dozens of fixes and performance improvements. Happy pulling! 🎉
```

---

## Promotional Text (170 max)

```
Attack of the Vine is here! Scan all 242 new cards on day one, flex your pulls
with shareable haul cards, and build smarter decks. 3.0 is our biggest update yet.
```
(~160 characters — re-count after any edit.)

---

## Subtitle (unchanged, 30 max)

```
Lorcana Collection Tracker
```

## Keywords (100 max)

```
lorcana,trading cards,tcg,collection,card tracker,deck builder,disney,card game,ccg,scanner
```
(Same as current — still the right head terms. Set names like "attack of the vine"
belong in the description/promo text, not the keyword field; brand + category terms
convert better there.)

---

## Description (refresh — replaces current)

Key changes vs. the 1.0 description: adds share cards, AI tools (Pro), Cardmarket
pricing, 13 sets, deck QR sharing; **fixes the now-inaccurate privacy paragraph**
(the old one claims "we never collect or transmit anything" — the app now uses
TelemetryDeck analytics, optional iCloud sync, and has a Pro subscription).

```
The Ultimate Disney Lorcana Collection Manager

Ink Well Keeper is your all-in-one companion for your Disney Lorcana TCG
collection. Scan cards in seconds, watch your collection's value, complete sets,
build decks, and show off your best pulls.

📸 SCAN ANY CARD IN SECONDS
Point your camera at any Lorcana card — or a whole stack of them. Batch scanning
recognizes card after card, then lets you review and add everything at once.
Foils, Enchanteds, and promos included.

🎴 TRACK EVERY SET
All 13 Lorcana sets, from The First Chapter to Attack of the Vine, plus promo and
special sets. Set completion bars, missing-card filters, and search by collector
number make finishing a set genuinely satisfying.

💰 KNOW WHAT IT'S WORTH
Live market pricing shows your total collection value, individual card prices,
and your top most-valuable cards.

🎉 SHARE YOUR PULLS
Just ripped a box? Generate a beautiful share card of your haul — top pull,
card count, total value — and post it anywhere. Single-card flexes, deck
showcases, collection milestones, and a collection recap round out five share
styles, each with a QR code friends can scan to open the app.

🃏 BUILD AND SHARE DECKS
Create unlimited decks with validation for Core, Infinity, and Casual formats.
See your cost curve, inkable ratio, and which cards you still need. Share any
deck as a QR code or link — friends can import it with one tap.

🤖 AI TOOLS (INK WELL KEEPER PRO)
• AI Deck Builder: describe the deck you want and get a legal 60-card list built
  around your collection and format rules.
• Rules Assistant: ask about card interactions and get clear answers with your
  card in context.

📊 BEAUTIFUL STATISTICS
Rarity donut, ink-color breakdown, cost curve, value by set, recent additions,
and more.

⭐ WISHLIST & IMPORTS
Track the cards you're hunting, with prices. Import your existing collection
from Dreamborn CSV or plain card lists in minutes.

☁️ iCLOUD SYNC (⚠️ include only if verified)
Your collection syncs privately across your devices via iCloud.

PERFECT FOR
✓ Collectors completing sets
✓ Players building competitive decks
✓ Traders watching card values
✓ Anyone opening boosters on set weekend

FREE TO USE
All collection tracking, scanning, pricing, sets, decks, and sharing are
completely free. Ink Well Keeper Pro is an optional subscription that unlocks
the AI Deck Builder and Rules Assistant.

PRIVACY
Your collection lives on your device (and in your private iCloud, if you enable
sync). We use privacy-first, anonymized analytics to improve the app — never
ads, never selling data.

LEGAL
This app uses trademarks and/or copyrights associated with Disney Lorcana TCG,
under Ravensburger's Community Code Policy. It is not published, endorsed, or
specifically approved by Disney or Ravensburger.

Questions or feedback? support@inkwellkeeper.app
```

---

## App Review notes — MUST update

The saved 1.0 review notes claim "No in-app purchases or subscriptions (free app)"
and "no server-side data collection." Both are now false and a rejection/metadata
risk. Update to:

- App now offers the **"Ink Well Keeper Pro"** auto-renewing subscription via
  RevenueCat (unlocks AI Deck Builder + Rules Assistant). Everything related to
  Lorcana card content remains free, per Ravensburger's Community Code Policy
  (policy URL: https://cdn.ravensburger.com/lorcana/community-code-en).
- Anonymized analytics via TelemetryDeck; optional private-database iCloud sync.
- AI features call OpenAI via the app; Rules Assistant capped at 50 questions/day.
- Provide a sandbox path for reviewers to see the paywall and, if required, a
  promo/sandbox subscription to exercise the AI features.

## Pre-submission checklist (3.0-specific)

- [ ] `MARKETING_VERSION` → 3.0.0
- [ ] Fix dummy App Store ID `id123456789` in `SettingsView.swift` rate-app link
- [ ] Remaining screenshots: AI hero, BUILD, MASTER (iPhone) + full iPad set
- [ ] Verify iCloud sync on two devices → decide on ⚠️ items above
- [ ] In-app What's New updated for 3.0
- [ ] Privacy nutrition labels reflect TelemetryDeck + iCloud + RevenueCat
- [ ] Manual-release selected; target release morning of Fri Jul 17, 2026
```
