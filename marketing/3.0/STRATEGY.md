# Ink Well Keeper 3.0 — Launch Marketing Strategy

**Version:** 3.0 (currently 2.3.1)
**Anchor date: Friday, July 17, 2026 — "Attack of the Vine!" (Set 13) street date.**
Every part of this plan is timed to that release. Set weekends are when the entire
Lorcana community is opening boosters, checking prices, and posting pulls — exactly
what 3.0's headline features (multi-scan, haul share cards, live pricing) are for.

---

## 1. Positioning

**One-liner:** *The fastest way to scan, track, and flex your Lorcana collection — ready for Attack of the Vine on day one.*

**Pillars (in priority order):**

1. **Day-one set support** — all 242 Attack of the Vine cards, scannable at launch.
2. **Share your pulls** — five branded share cards (Haul, Card Flex, Deck, Milestone, Collection Review) with QR codes that open the app or the App Store. This is both a feature *and* the growth engine.
3. **Scan fast** — redesigned multi-card batch scanning with a review step.
4. **Smarter decks** — redesigned deck tab, deck sharing via QR/link, AI Deck Builder + Rules Assistant (Pro).
5. **Know your value** — Cardmarket live pricing, reworked stats with charts.
6. **Everywhere** — iCloud sync across devices. ⚠️ *Only claim this if it's verified working on two devices before submission — it was wired recently and is listed as runtime-unverified. If unverified, cut it from all copy.*

**Audiences:**
- **Set-weekend collectors** (primary): opening AotV boosters July 17–19, want to log pulls fast and show them off.
- **Competitive players**: deck building, format validation, deck sharing before locals.
- **Value trackers**: collection worth, price trends, trade decisions.

## 2. The growth loop (make the product do the marketing)

Every share card carries the wordmark + a QR code → Universal Link → app if installed, App Store if not. The strategy is to get share cards into feeds during set weekend:

- Seed it yourself: post your own AotV haul cards (Reddit, X, Discord, FB) launch weekend.
- The in-app moment: after a multi-scan session ends, the haul share prompt IS the campaign. Make sure that flow is frictionless before submission.
- Optional (30 min of dev work, high value): append `?src=share` to the Universal Link the QR encodes, and log a TelemetryDeck event when the app is opened via deep link, so share-driven installs/open are measurable.

## 3. Channels & actions

| Channel | Action | When |
|---|---|---|
| **App Store (ASO)** | New What's New, promo text, refreshed description/keywords (see `APP_STORE_3.0.md`); finish remaining screenshots (AI hero, BUILD, MASTER, iPad set) | Before submission |
| **App Store featuring** | Submit a featuring nomination in App Store Connect (Promote your app form), pitching the AotV day-one timing | ASAP — Apple needs lead time |
| **r/Lorcana** | Launch post (copy in `LAUNCH_POSTS.md`) — lead with utility + haul share example, transparent "I'm the dev" framing; check sub self-promo rules first & engage in comments all day | Fri Jul 17 morning |
| **Lorcana Discords** (community servers, LGS servers) | Short announcement in self-promo/community-tools channels | Jul 17–18 |
| **Facebook groups** (Lorcana Players/Collectors groups) | Same post adapted; FB skews collector-heavy — lead with haul value + set tracking | Jul 17–18 |
| **X / Twitter** | Launch thread + your own AotV pull share-cards over the weekend | Jul 17–19 |
| **TikTok / IG Reels / Shorts** | 15–30s vertical: hand-scanning a stack of AotV cards → haul card appears → "that's my whole box logged." Raw phone-screen recording is fine; authenticity beats polish here | Weekend + ongoing |
| **Creators** | Email/DM 5–10 Lorcana YouTubers & podcasters (box-opening channels especially) offering a promo look; template in `LAUNCH_POSTS.md` | Send Jul 13–15 |
| **Website** | Real landing page replacing the redirect stub (done — `Website/index.html`), OG tags so shared links unfurl nicely | Deploy before Jul 17 |

**Skip / deprioritize:** Product Hunt (wrong audience for a TCG niche tool), paid ads (no budget signal; the share-card loop is the paid-ads substitute).

## 4. Timeline

**Week of Jul 6 (this week) — build & submit**
- [ ] Verify iCloud sync on two physical devices (decides whether it's a headline)
- [ ] Fix the dummy App Store ID in the Settings "rate app" link (`SettingsView.swift`) — review generation depends on it
- [ ] Bump `MARKETING_VERSION` to 3.0.0, update in-app What's New
- [ ] Finish remaining ASO screenshots (AI hero, BUILD, MASTER; iPad set) — `aso-appstore-screenshots` flow already set up
- [ ] Update App Store Connect metadata from `APP_STORE_3.0.md` — **including Review Notes: the old notes say "no IAP"; the app now has the Ink Well Keeper Pro subscription. Stale notes are a rejection risk.**
- [ ] Submit by **Wed Jul 9–Thu Jul 10** (buffer for a review round-trip), select **manual release**
- [ ] Submit App Store featuring nomination
- [ ] Deploy new landing page; verify AASA still serves

**Week of Jul 13 — pre-launch**
- [ ] Approved build held for manual release
- [ ] Creator outreach emails (Jul 13–15)
- [ ] Record scan/haul demo video with real cards
- [ ] Prep all posts from `LAUNCH_POSTS.md`; check r/Lorcana self-promo policy

**Fri Jul 17 — launch day (set street date)**
- [ ] Release 3.0 in the morning
- [ ] Reddit post, Discord announcements, X thread, FB groups
- [ ] Buy/open AotV product; post your own haul share cards
- [ ] Reply to every comment; hotfix build ready if scanning hiccups on new cards

**Jul 18–31 — sustain**
- [ ] Short-form clips 2–3×/week while AotV hype lasts
- [ ] Respond to App Store reviews (esp. negative) within 24h
- [ ] Week-2 retro: TelemetryDeck scan/share numbers, App Store impressions → conversions
- [ ] Follow-up post: "what people pulled" / most-scanned AotV cards (aggregate, anonymized) if data supports it

## 5. Measurement (TelemetryDeck + App Store Connect)

Track weekly: downloads, App Store impressions→install conversion, scan sessions, share-card renders/shares (add events if missing), deep-link opens (share-loop signal), Pro trial starts/conversions, ratings count & average.

**Success bar for launch month:** downloads ≥3× June baseline; ≥10% of active users generate a share card; rating holds ≥4.5.

## 6. Compliance guardrails (don't skip)

- Ravensburger **Community Code Policy**: keep all Lorcana content (card data, images, tracking) free to access. Pro gates *your* AI features, not Lorcana content — keep it that way and say so in App Review notes.
- Keep the "not endorsed by Disney/Ravensburger" disclaimer on the website footer and in posts where required by group rules.
- Reddit/Discord/FB self-promo rules: read each community's policy before posting; prefer "dev of a free community tool" transparency framing.
