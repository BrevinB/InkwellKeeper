# Press outreach — targets & pitch drafts

Companion to the press kit at **https://inkwellkeeper.app/press/** (assets zip:
`/assets/press/ink-well-keeper-press-kit.zip`). Creator outreach (YouTube,
podcasts, TikTok) lives separately in `marketing/3.0/CREATOR_OUTREACH.md` —
this file covers **written press**: TCG/Lorcana media and Apple/indie-app press.

Log every send in `marketing/outreach_log.md` (same tracker as creators, so
nobody gets double-pitched). Playbook rules apply: personalize before sending,
one follow-up after ~a week, then stop.

**Contact addresses are not listed here on purpose** — look up each outlet's
current tips email or contact form yourself right before sending (mastheads
and tip lines change; a stale address bounces or lands with someone who left).

---

## Group 1 — TCG / Lorcana media (highest hit rate, do these first)

| Outlet | Focus | Where to find contact | Angle to lead with |
|---|---|---|---|
| **TCGplayer Infinite** | Lorcana strategy/news articles | Author bios / TCGplayer content team page | Live pricing + collection value (pricing is their world) |
| **Polygon** (tabletop desk) | Covered Lorcana heavily since launch | Tips email on site / individual tabletop writers on socials | Solo-dev story + the scanner demo video |
| **Dot Esports** | Lorcana news & guides section | Tips/contact page | Set-release-day support; useful tool for their guide readers |
| **Dexerto** | TCG news, market/collector stories | Tips form | Collection value / market angle |
| **TheGamer** | Tabletop + Lorcana features | Pitches/contact page | Feature-y solo-dev angle |
| **Cardmarket Insight** (EU) | TCG market blog | Cardmarket editorial contact | Pricing/collection-value angle for EU collectors |
| **LorcanaPlayer.com** | Dedicated Lorcana fansite | Site contact form | Community tool — likely the easiest yes |

Community channels (not press, different etiquette — check each community's
self-promo rules and post as a participant, not an advertiser):
**r/Lorcana** (dev-post with a genuine "I built this, AMA" framing, mods often
allow it), **Lorcania** resource listing, major Lorcana Discords'
self-promo/resources channels.

### Template A — TCG/Lorcana media

Subject: `Free iOS app scans a whole Lorcana box in minutes — [hook: next set / feature launch]`

```
Hi [Name],

I'm Brevin, the solo developer behind Ink Well Keeper, a free iOS app for
Disney Lorcana collectors. I read your [specific recent article — no genuine
reference, no send], and thought this might be worth a look for [outlet]'s
readers ahead of [hook — e.g., the next set release]:

• Batch camera scanning — a whole booster box logged in minutes, with live
  per-card market prices and total collection value
• Set completion across all 13 sets plus promos, with foil/Enchanted/Epic/
  Iconic variants tracked separately
• Deck builder with Core/Infinity format legality checking and deck sharing
  via links that open in any browser
• New sets supported day one (all 242 Attack of the Vine cards were live at
  launch)

It's free with no ads — everything Lorcana-related stays free; only two AI
extras (deck builder + rules assistant) sit behind an optional Pro tier.

Press kit with fact sheet, screenshots, and assets:
https://inkwellkeeper.app/press/

Happy to send a short demo video of a live box-scan, Pro promo codes, or
answer anything directly — I'm a one-person shop, so you're talking to the
person who wrote the code.

Thanks for the Lorcana coverage — [one genuine closing line about their work].
— Brevin Blalock
support@inkwellkeeper.app · https://inkwellkeeper.app
```

---

## Group 2 — Creators

Already drafted and targeted in `marketing/3.0/CREATOR_OUTREACH.md` (10
personalized drafts + TikTok DMs). Add the press-kit link to those sends going
forward: `https://inkwellkeeper.app/press/` gives them thumbnails, the icon,
and b-roll screenshots without asking you for files.

---

## Group 3 — Apple / indie-app press (~5 careful pitches, not a blast)

Lower hit rate; only worth genuinely personalized sends. The angle that works
here is **not** "Lorcana app exists" — it's *solo dev + camera-ML scanner +
privacy-first (on-device data, no accounts) + free where it counts*.

| Outlet | Where to find contact | Notes |
|---|---|---|
| **MacStories** | Tips email on site | Best fit — they love polished indie apps with a story; a great demo video matters most here |
| **9to5Mac** | Tips form/email | Frame as indie-app spotlight |
| **MacRumors** | Tips email | News peg needed (major version or set-day update) |
| **Cult of Mac** | Contact page | Covers indie app roundups |
| **The Sweet Setup** | Contact page | "Best app for X" format — pitch as *the* Lorcana collection app |

### Template B — Apple/indie press

Subject: `Solo-built iOS app: point your camera at a stack of trading cards, get a valued collection`

```
Hi [Name],

I'm Brevin Blalock, a solo iOS developer. I built Ink Well Keeper, a free
iPhone/iPad app for Disney Lorcana (the Disney trading card game) that I
think fits [outlet]'s indie-app coverage — [reference a specific recent
piece; no genuine reference, no send].

The short version: point the camera at a stack of cards and the app
recognizes each one, logs it, and prices it with live market data — a full
booster box in minutes. SwiftUI throughout, on-device collection data with
private iCloud sync, no accounts, no ads. There's also an AI deck builder
that completes decks from cards you actually own, and format-legal deck
sharing via links that open in any browser.

Lorcana's collector base has grown fast and the tooling was mostly
spreadsheets — this has been my nights-and-weekends answer to that.

Press kit (fact sheet, screenshots, icon, demo video on request):
https://inkwellkeeper.app/press/
App Store: https://apps.apple.com/us/app/ink-well-keeper/id6754206379

Happy to send a Pro promo code or a 30-second scanning demo video, or to
answer anything about how the scanner works under the hood.

Thanks either way — [one genuine closing line].
— Brevin
support@inkwellkeeper.app
```

### Follow-up (either group, send once, ~7 days later)

```
Hi [Name] — following up once on Ink Well Keeper (free iOS Lorcana collection
scanner) in case it got buried. Since I wrote, [one new thing: milestone,
feature shipped, set announced]. Press kit: https://inkwellkeeper.app/press/
No worries at all if it's not a fit — I won't email again after this.
— Brevin
```

---

## Timing pegs (don't pitch without one)

1. **Next set release** — strongest peg; pitch 1–2 weeks before street date
   with "day-one support + early access."
2. **Web deck viewer / short-link sharing launch** (product backlog) — good
   peg for TCG media ("share a decklist that opens in the browser").
3. **A milestone** — downloads, cards scanned, rating count worth citing.

## Checklist before any send

- [ ] Current contact verified on the outlet's own site (never reuse old ones)
- [ ] Every `[bracket]` filled with a genuine, specific reference
- [ ] Hook/peg named in the subject line
- [ ] Logged in `marketing/outreach_log.md` with date + what was pitched
- [ ] Promo codes generated in App Store Connect for the current version
