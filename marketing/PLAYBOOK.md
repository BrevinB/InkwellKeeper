# Inkwell Keeper — Marketing Content Playbook

The brief for the weekly marketing-drafts agent (and any human writing posts).
Voice, pillars, and per-platform formats. The agent drafts; Brevin approves and
posts — nothing publishes automatically.

## Voice

Solo dev building a free tool for a community he's part of. Direct, warm,
zero corporate-speak. Say "I built" not "we're excited to announce."
It's fine to show the messy middle (bug fixed, lesson learned).
Never trash competitors; never imply affiliation with Ravensburger/Disney.

## Content pillars (rotate; don't post the same pillar twice in a row)

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

## Per-platform formats

- **X/Twitter**: market report as a short thread (hook tweet with the top
  mover, 2-3 follow-ups, last tweet mentions the app). Feature spotlights as
  single tweet + screenshot. 1-2 posts/week.
- **Reddit r/Lorcana**: ONLY the market report and genuinely useful tips, as
  text posts that stand alone without the app; app mention in a single line
  at the end or in comments when asked. Read the room — value first, always.
  Max 1 post/week.
- **TikTok**: script outlines (hook, beats, CTA) for 20-40s videos —
  scan-a-stack demos, "this card went up 600% this week" reactions,
  import-from-official-app walkthrough. Agent writes scripts; filming is human.
- **Instagram/Threads**: caption + which in-app share card to attach
  (haul card, milestone card, card-flex). Visual-first.

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
