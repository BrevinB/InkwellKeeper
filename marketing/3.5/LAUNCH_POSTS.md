# Ink Well Keeper 3.5.0 — launch posts (storage + Bookshelf, into Hyperia City)

**Timing peg:** 3.5.0 is live now; Hyperia City (Set 14, 204 cards) releases **Fri Oct 16**.
**Story in one line:** "Which binder is that card in?" — now you know.
**Instagram calendar:** `marketing/drafts/ig-week-2026-10-13.md`.
**Assets:** `marketing/drafts/images/2026-10-13/` (4 IG feed images + `x-launch-1600x900.png`), `marketing/drafts/reels/2026-10-13/reel-storage-launch.mp4` (14s, silent).
**Regenerate assets:** `python3 marketing/3.5/src/make_launch_images.py` then `zsh marketing/3.5/src/make_reel.sh`.

**Free vs Pro — keep every post honest:**
- **Free:** up to 3 binders/boxes, page-turning binders, the Bookshelf + sharing it, bulk moves, deck boxes for built decks (these don't count toward the 3).
- **Pro:** unlimited binders/boxes, Starlight & Holofoil finishes, set checklist binders (incl. master set), scanning straight into a binder.

Voice rules from `PLAYBOOK.md` apply: "I built", no corporate-speak, never imply affiliation with Ravensburger/Disney.

---

## 1. X (@inkwellkeeper)

**Tue Oct 13 — launch (attach `reel-storage-launch.mp4`)**
```
"Which binder did I put that card in?"

Ink Well Keeper 3.5 is out: track every binder, trove and deck box you own. Flip through binders page by page, see every box on your Bookshelf, find any card in a tap.

Free on iOS 👇
https://apps.apple.com/us/app/ink-well-keeper/id6754206379
```

**Wed Oct 14 — build-in-public thread (attach `ig-03-pick-your-binder.png` to tweet 1, the bookshelf capture to tweet 3)**
```
1/ Every binder and box in Ink Well Keeper is a real 3D render. I modeled them in Blender — leather grain, gold corners, stitching — then the app tints them to whatever colour you pick.

2/ One render per shape, eight colours from it: the app multiplies your colour over a lit "white leather" layer, so the lighting and gold trim stay real. Keeps the whole set under a megabyte.

3/ Then I built a Bookshelf for them. Tap a binder: it slides off the shelf, turns to face you, and the cover swings open onto the real first page.

4/ Spent way too long on a page-turn animation. Zero regrets. 📚
https://apps.apple.com/us/app/ink-well-keeper/id6754206379
```

**Thu Oct 15 — midweek (attach `ig-02-binder-page.png`)**
```
Set checklist binders: every Hyperia City card gets its own numbered pocket, and the empty ones show you exactly what you're missing.

Ready for tomorrow. 🏙️
```

**Fri Oct 16 — set day (attach `ig-04-hyperia-city-day.png`)**
```
Hyperia City is out! 🏙️✨

All 204 cards are in Ink Well Keeper. Scan your pulls in seconds, see what they're worth, and file them straight into a binder.

What was your best pull?
```

**Sat–Sun — replies, not posts.** Spend the ~10 min/day from the playbook replying to Hyperia City pack-opening posts and "what's this worth" questions. Mention the app only when it answers the question.

**Ad hoc build-in-public (post only if true):** the first storage bug report → fix story ("reported this morning, fixed in review tonight").

---

## 2. Reddit — r/Lorcana (1 post this week; tip first, app last)

Per the playbook, Reddit gets genuinely useful content that stands alone without the app. This is a binder-planning guide timed for release week; the app is one line at the end.

**Title:** `Planning binder space for Hyperia City (and a master set) — the page math`

```
With Hyperia City dropping Friday, here's the binder math I worked out so I'm not re-sleeving everything in a month. The main set is 204 cards.

**One copy of each card**
- 9-pocket pages: 204 ÷ 9 = 23 pages → 12 double-sided sheets
- 12-pocket pages: 17 pages → 9 sheets
- 4-pocket pages: 51 pages → 26 sheets
- A standard 20-sheet 9-pocket binder (360 pockets) fits one set with ~150 pockets to spare — enough for the specials too.

**Master set (normal + foil side by side)**
- 408 pockets for the main set, before Enchanted/Epic/Iconic
- 9-pocket: 46 pages → 23 sheets — you'll outgrow a 20-sheet binder
- 12-pocket: 34 pages → 17 sheets

**Tips that saved me headaches**
1. Leave the pocket empty when you're missing a card. Filling gaps later beats re-sleeving everything to keep numbers in order.
2. Put each foil directly next to its normal copy. Missing foils jump out when you flip through.
3. Specials (Enchanted/Epic/Iconic) go at the back in their own pages. They're numbered after the main set, and keeping them separate means a late pull never shifts your main pages.
4. Label the spine with the set name. Sounds obvious until you have six identical black binders.

Full disclosure, I build Ink Well Keeper (free iOS app). It now does this tracking for you, including a checklist binder that shows the missing cards in their numbered pockets. Happy to answer anything about the math either way.
```

*If someone asks for the app in comments:* reply with the App Store link, plus one sentence on the set checklist binder. Don't post the link in the body.

---

## 3. Threads

**Tue Oct 13 (attach `ig-01-storage-hero.png`)**
```
I built a bookshelf for your Lorcana binders. 📚 Every binder, trove and deck box you own — flip through pages, pull a binder off the shelf, find any card in a tap. Ink Well Keeper 3.5, free on iOS.
```

**Fri Oct 16 (attach `ig-04-hyperia-city-day.png`)**
```
Hyperia City is out 🏙️ Scan your pulls, see what they're worth, file them straight into a binder. Best pull so far?
```

---

## 4. Reel / TikTok scripts (film once, post both)

TikTok CTA rule from the playbook: there's no bio link yet, so say **"search Ink Well Keeper on the App Store,"** never "link in bio." Instagram can use "link in bio."

**Recording:**
- **Simulator:** `xcrun simctl io booted recordVideo --codec h264 ~/Desktop/clip.mp4` (Ctrl-C to stop). Turn off What's New first: `xcrun simctl spawn booted defaults write co.brevinb.Inkwell-Keeper LastSeenWhatsNewVersion -string 3.5.0`.
- **Device:** Control Center screen recording.
- **Status bar:** `xcrun simctl status_bar booted override --time 9:41`.
- **Composing:** drop clips in `marketing/drafts/`, then ask me to put them on the brand background with captions.

### Reel 2 — "Where is that card?" (the hero; 15–20s)
1. **Hook (0–2s)**, on-screen text: *"POV: you know you own it… somewhere"*. Show the Collection tab, then type a card name.
2. **(2–6s)** Open the card. The "Stored In" section shows *Winterspell* with *p.4, pocket 7* under it.
3. **(6–14s)** Bookshelf tab: tap the Winterspell binder. It lifts off the shelf, turns, the cover swings open, and the page lands on the card.
4. **(14–18s)** Text: *"Every binder. Every box. Finally organized."*
5. **CTA:** IG "Free on iOS · link in bio" / TikTok "search Ink Well Keeper on the App Store."

### Reel 3 — Hyperia City day (film Fri Oct 16; 20–30s)
1. **Hook:** a sealed Hyperia City pack in hand. *"Opening Hyperia City and organizing it live."*
2. Rip the pack and fan the cards (real footage, phone on a stand).
3. Multi-scan the stack, with the recognition pills popping.
4. Put them into a Hyperia City checklist binder: the pockets fill and the empty ones stay faded.
5. Flip a page. Text: *"14 cards down, 190 to go."* (Use your real count.)
6. **CTA:** as above. **Caption:** *"Hyperia City binder: started. 🏙️ #Lorcana #HyperiaCity"*

### Reel 4 — page-turn ASMR (10–15s, loop-friendly)
1. No hook text. Open a full binder and slowly drag-turn 4–5 pages, enchanteds if you can.
2. End on a full page. Text: *"flip it like the real thing"*.
3. Make it loop: end on the same page you started on.

### Reel 5 — "Pick your binder" (5–8s, quick)
1. Open the Create Binder sheet and tap through the colours, so the preview changes colour with each tap.
2. Text: *"which one's yours?"*. The comments do the rest.

---

## 5. Discord / Facebook groups (only where self-promo is allowed — check each server's rules)

```
Hey all! Built something for the binder people here. 📚

Ink Well Keeper (free iOS app) now tracks your physical storage: binders you flip through page by page, troves, deck boxes, bulk bins. Tap a card and it tells you which binder and pocket it's in. Set checklist binders show which numbered pockets you're still missing.

Timed it for Hyperia City on Friday. Feedback very welcome, I'm the solo dev and I read everything.
https://apps.apple.com/us/app/ink-well-keeper/id6754206379
```

---

## 6. Website copy (`inkwellkeeper-site` — new storage section)

**Section heading:** Every binder. Every box.
**Subhead:** Know exactly where every card lives.

**Feature blurbs (3 columns):**
- **Binders you can flip through.** 4, 9 or 12-pocket pages that turn like the real thing. Drag cards between pockets, or auto-fill from your unsorted pile.
- **A Bookshelf for everything.** Troves, deck boxes, storage boxes and bulk bins sit on a wooden bookcase. Pull a binder off the shelf and it opens in your hands.
- **Set checklists.** A binder for one set puts every card in its numbered pocket and shows the ones you're still missing. Go master set with foils side by side. *(Pro)*

**FAQ addition:**
> **Can I track which binder my cards are in?**
> Yes. Since version 3.5, Ink Well Keeper tracks binders, troves, deck boxes, storage boxes and bulk bins. Open any card to see exactly where each copy is stored. Up to three binders and boxes are free; Pro adds unlimited storage and set checklist binders.

**On Oct 16:** change the Attack of the Vine banner to Hyperia City, change "13+ sets" to "14 sets", and bump the sitemap `lastmod`.
