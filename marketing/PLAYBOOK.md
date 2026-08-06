# Inkwell Keeper — Marketing Content Playbook

The brief for the weekly marketing-drafts agent (and any human writing posts).
Voice, pillars, and per-platform formats. The agent drafts; Brevin approves and
posts — nothing publishes automatically.

## Voice

Solo dev building a free tool for a community he's part of. Direct, warm,
zero corporate-speak. Say "I built" not "we're excited to announce."
It's fine to show the messy middle (bug fixed, lesson learned).
Never trash competitors; never imply affiliation with Ravensburger/Disney.

## Content pillars

1. **Market report** — weekly movers from `Scripts/market_report.py`. Our own
   price-history data; nobody else can post this. Always eyeball the numbers
   before posting — a +600% move can be a thin-market blip.
2. **Feature spotlights** — one feature, shown doing its job (official-app
   import, price history chart, set filters, scan-a-stack). Pull from recent
   release notes / git history, not imagination.
3. **Collector tips** — how to track pulls, when foils diverge from normals,
   set-completion strategies. Teach first, mention the app second.
4. **Build-in-public** — what got fixed/shipped this week and why. The
   "user reported → fixed in a day" story is the brand.

### Rotation (enforced, not vibes)

Each week has ONE **primary pillar** that leads the X post and the Reddit
post. Rotate through all four pillars over a month — check the last 2-3
editions in `marketing/drafts/` and pick the least-recently-led pillar.
**The market report must not lead two weeks in a row.** When it isn't
primary, the market data still earns a short secondary slot (one tweet in
the thread, one line in the Reddit post) or gets skipped entirely if
nothing credible moved. TikTok's two scripts should cover two different
pillars; Instagram/Threads can follow any pillar with a visual.

### Non-price topic bank (real features — never invent beyond these)

Collection tracking: scan a whole stack at once with multi-scan review ·
collection value + stats dashboard · set completion tracking with
ownership/rarity/ink/price filters · wishlist · foil vs normal tracked as
separate printings · iCloud sync across devices · lore counter for game
night · starter deck one-tap add.

Import/export: official Disney Lorcana app import (paste backup link —
nobody else has this) · Collectr CSV · Dreamborn (now seconds, not
minutes) · full collection export.

Extras: AI deck builder · rules assistant · branded share cards (haul,
milestone, card-flex) · price history chart on every card · real Lorcana
symbols in card text · offline card images.

## Per-platform formats

- **X/Twitter** (@inkwellkeeper): 2-4 originals/week, spread across
  different days, never more than one per day — consistency beats volume.
  **Monday**: the week's primary-pillar post (market report runs as a short
  thread: hook tweet with the top mover, 2-3 follow-ups, app-link close;
  other pillars as single post + screenshot). **Midweek**: a lighter single
  post from a *different* pillar (feature screenshot, a price-history chart
  of a mover). **Ad hoc**: build-in-public moments posted when they're
  true — "reported this morning, fix in review tonight" beats anything
  scheduled. Skip filler; an empty day is better than a weak post.
- **Reddit r/Lorcana**: ONLY the market report and genuinely useful tips, as
  text posts that stand alone without the app; app mention in a single line
  at the end or in comments when asked. Read the room — value first, always.
  Max 1 post/week.
- **TikTok** (@inkwellkeeper): script outlines (hook, beats, CTA) for
  20-40s videos — scan-a-stack demos, "this card went up 600% this week"
  reactions, import-from-official-app walkthrough. Agent writes scripts;
  filming is human. Aim to film 1-2 of the weekly scripts. CTA caveat:
  the account has NO bio link until 1k followers (or a Business-account
  switch) — until then CTAs must say "search Ink Well Keeper on the App
  Store," never "link in bio."
- **Instagram/Threads**: PRIORITY CHANNEL (verified driving downloads and
  subscriptions, Aug 2026) — one feed post per day, planned as a weekly
  calendar (see `drafts/ig-week-*.md` for the format: hook first line,
  CTA "Free on iOS · link in bio", 4 hashtags). Visual-first: branded
  1080×1350 images in the app-theme style (gradient + gold sparkles +
  ink ribbon; see `drafts/images/`), rotating through feature spotlights,
  share-card showcases, and one market-data post per week with real
  backend numbers. Reels outperform static posts (verified Aug 2026):
  prefer Reels where footage or an animated data story exists — screen
  recordings composed onto the brand background, or generated
  market-data reels; statics become next-morning story reshares. Reels
  ship silent; add a trending audio track in the IG composer at post
  time. TikTok script outlines double as Reel scripts — film once,
  post both. Reshare each post to the story the next morning.
  Prices must be real; collection/haul stats may be demo values (App
  Store screenshot convention).

## X engagement & outreach (human-only — not for the drafts agent)

Original posts from a small account reach almost nobody; replies reach the
*other* account's audience. This is the actual growth engine.

Daily habit (~10 min):
- Reply as a knowledgeable collector to pack-opening posts, "what's this
  card worth" questions, market chatter, and Lorcana creator threads.
  Value first — mention the app only when it directly answers the question
  (a real price plus "I track these daily in the app I build" is fine).
- Be a familiar face, not a barnacle: don't reply to the same creator
  repeatedly in a short window, and never reply just to be seen.
- Follow community accounts as they appear; congratulate big pulls.

Creator DMs:
- Templates and tone live in `marketing/3.0/CREATOR_OUTREACH.md`; lead
  with the official-app import differentiator.
- Engage genuinely with a creator's content for a week or two before
  DMing — a cold DM from a fresh brand account reads as spam.
- Max 2-3 outreach DMs per week. Log every attempt (who, date, channel,
  response) in `marketing/outreach_log.md` so nobody gets double-pitched.
- If DMs are closed or ignored, `brevin@inkwellkeeper.app` is the
  fallback channel — same template, same tone.
- X Premium ($8/mo, subscribe on web, not iOS): worth it once DM outreach
  starts (checkmark, DM reach, reply ranking). Not needed before then.

## Standing rules

- No engagement bait, no fake urgency, no giveaway posts without Brevin
  planning them deliberately.
- Prices/claims must come from the market report script or the app itself.
- "Import from the official Lorcana app" is the differentiator — work it in
  whenever natural, never more than once per platform per week.
- Credit community tools when relevant (LorcanaExporter, lorcana-icons).
- App Store link: https://apps.apple.com/us/app/ink-well-keeper/id6754206379

## Sources of truth for the agent

- `Scripts/market_report.py --days 7 --top 5` — market data
- `git log --oneline --since="1 week ago"` — what actually shipped
- `marketing/3.1/RELEASE_NOTES.md` — current release messaging
- `marketing/3.0/CREATOR_OUTREACH.md` — outreach templates and tone
