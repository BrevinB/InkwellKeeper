# Countdown reel templates

Reusable 1080x1920 HTML templates for "Top N cards" Instagram reels (see
`marketing/drafts/reels/`). Placeholders: `{{TITLE}}`, `{{SUBTITLE}}` (bg/intro),
`{{BG}}`, `{{IMG}}`, `{{RANK}}` (frame). Pipeline: capture card screens with the
simulator filming rig (DEBUG `-deeplink` launch arg), substitute + screenshot each
page with headless Chrome (no `--user-data-dir`!), then ffmpeg zoompan segments and
concat. Reference run: session notes in auto-memory `marketing-automation`.
