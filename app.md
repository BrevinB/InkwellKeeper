# Ink Well Keeper — App Store Listing & SEO Keyword Research

_Last updated: 2026-07-08. Source: [App Store listing](https://apps.apple.com/us/app/ink-well-keeper/id6754206379) (iTunes Lookup API + web listing scrape)._

## 1. App Store Listing Data

| Field | Value |
|---|---|
| App name | Ink Well Keeper |
| App ID | 6754206379 |
| Developer | Brevin Blalock |
| Price | Free (with Pro in-app purchases) |
| Rating | 4.7 ★ (22 ratings) |
| Categories | Reference, Utilities |
| Current version | 2.3.1 (released 2026-06-04) |
| First released | 2025-11-19 |
| Minimum OS | iOS 17.6 |
| Size | ~718 MB |
| Devices | iPhone & iPad |
| Store URL | https://apps.apple.com/us/app/ink-well-keeper/id6754206379 |

### Full description (verbatim)

> The ultimate companion for managing your Disney Lorcana TCG collection. Whether you're completing sets, building decks, or tracking your collection's value — Inkwell Keeper makes it effortless.
>
> **SCAN & ADD INSTANTLY** — Point your camera at any Lorcana card and it's added to your collection automatically. Multi-scan mode lets you add stacks of cards in seconds. Attach photos of your physical cards to keep a visual record.
>
> **TRACK EVERY CARD** — All 12 sets plus promos, always up to date. Track Normal, Foil, Enchanted, Epic, Iconic, and Promo variants. Visual set completion progress bars. Filter and sort by type, color, rarity, variant, and more.
>
> **IMPORT YOUR COLLECTION** — Dreamborn CSV import with live progress, paste-a-text-list import, starter deck presets.
>
> **BUILD COMPETITIVE DECKS** — Core Constructed, Infinity Constructed, and Triple Deck formats. AI-powered deck completion to 60 cards. AI strategy guide. Legality validation, mana curve, missing-cards view. Export and share deck lists.
>
> **KNOW YOUR COLLECTION'S VALUE** — Live market pricing, total collection value, individual card prices, quick retailer links.
>
> **WISHLIST** — Track needed cards, see pricing, quick purchase links.
>
> **BUILT FOR PERFORMANCE** — Fast with thousands of cards. Data stays on your device.
>
> Fan-made app; not affiliated with Disney or Ravensburger.

### Screenshot inventory (downloaded to `Website/assets/appstore/`)

| File | On-image headline | Shows |
|---|---|---|
| `iphone-1.jpg` | "Your Digital Card Binder" | My Collection grid with filters (type, color) |
| `iphone-2.jpg` | "Scan Cards Instantly" | Live camera scan recognizing a card, Auto Scan button |
| `iphone-3.jpg` | "Import Existing Collection" | Bulk Import: Dreamborn CSV + text list |
| `iphone-4.jpg` | "Complete Your Sets" | Card Sets screen with completion % bars per set |
| `iphone-5.jpg` | "Know Your Collection Value" | Collection Overview: 1,701 cards / $2,602.21, rarity breakdown |
| `iphone-6.jpg` | "Build Your Decks" | Deck builder: missing cards, cost curve, legality validation |
| `ipad-1.jpg` – `ipad-2.jpg` | Same campaign, iPad 13" layouts | Binder + scanner on iPad |
| `icon-1024.png` / `icon-512.png` / `icon-180.png` | — | App icon (inkwell + quill, dark navy + gold) |

## 2. Competitive Landscape (from SERP research)

Who currently ranks for our money keywords:

- **dreamborn.ink** — dominant web collection tracker + deck builder; no native scanning. Owns "lorcana collection tracker" SERP.
- **Official Disney Lorcana Companion app** (Ravensburger) — card catalog + basic tracker + lore counter; no scanning, no prices, no CSV import.
- **TCG Stacked** — web + app tracker with scanning, prices, binders. Ranks for "collection tracker" and "card prices".
- **Lorscana** — iOS scanner app, markets Dreamborn sync; owns "lorcana card scanner" SERP with a dedicated landing site (lorscana.com).
- **Price guides** — PriceCharting, TCGPlayer, tcgpricelookup, Sports Card Investor own "lorcana card prices/value" informational SERPs.
- **Deck-building content** — Lorcana Wiki (fandom), lorcanacollectors.com, retailer blogs own "lorcana deck building rules".

**Positioning gap Ink Well Keeper can own:** the only iPhone-native app that combines *batch scanning + full variant tracking (Enchanted/Epic/Iconic) + live value + AI deck building + Dreamborn import* — "everything dreamborn does, plus a scanner, in your pocket."

## 3. Keyword Strategy

### Primary keywords (landing page targets)

| Keyword | Intent | Where targeted |
|---|---|---|
| lorcana collection tracker | High — looking for exactly this | `<title>`, H1 area, hero copy |
| lorcana card scanner (app) | High — feature seekers, converts well | H2, hero sub, guide |
| disney lorcana app | Broad discovery | title tag, meta description |
| lorcana deck builder | High — second core job | features H2, guide |
| lorcana card prices / collection value | High commercial | features H2, guide |
| lorcana app iphone / ios | Qualified device intent | meta, copy |

### Long-tail keywords (guide pages — one page each)

| Keyword cluster | Guide page | Searcher's question |
|---|---|---|
| best way to track lorcana collection, lorcana collection tracker app | `/guides/lorcana-collection-tracker/` | "What's the best way to keep track of my cards?" |
| scan lorcana cards, lorcana card scanner iphone | `/guides/lorcana-card-scanner/` | "Can I scan my cards instead of entering them by hand?" |
| how much are lorcana cards worth, lorcana card value | `/guides/lorcana-card-value/` | "Are any of my cards valuable?" |
| lorcana deck building rules, how many cards in a lorcana deck | `/guides/lorcana-deck-building/` | "What are the deck rules? 60 cards, 4 copies, 2 inks?" |
| lorcana set checklist, lorcana sets in order | `/guides/lorcana-set-checklist/` | "Which sets exist and what's in them?" |
| dreamborn csv export/import, dreamborn app | `/guides/dreamborn-csv-import/` | "How do I move my Dreamborn collection into an app?" |
| enchanted lorcana cards, lorcana pull rates | `/guides/enchanted-lorcana-cards/` | "What are Enchanted cards and how rare are they?" |
| how to organize lorcana cards, lorcana binder | `/guides/how-to-organize-lorcana-cards/` | "How should I sort/store my collection?" |

### On-page SEO checklist applied

- One H1 per page, keyword-leading title tags ≤ 60 chars, meta descriptions 140–160 chars with CTA
- JSON-LD: `SoftwareApplication` + `FAQPage` on the landing page; `Article` + `BreadcrumbList` + `FAQPage` on guides
- Descriptive alt text on every screenshot (keyword-bearing, honest)
- Internal linking: landing → guides ("Learn more"), guides → landing + App Store (conversion), guides cross-link
- `sitemap.xml` + `robots.txt`
- Smart App Banner (`apple-itunes-app`) on every page
- Fast: single-file CSS, no external requests, lazy-loaded images, responsive

### Compliance note

All pages keep the Ravensburger Community Code disclaimer ("not published, endorsed, or specifically approved by Disney or Ravensburger") in the footer.
