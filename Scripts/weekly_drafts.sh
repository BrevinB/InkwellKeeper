#!/bin/bash
#
# Weekly marketing drafts — run Mondays by the com.inkwellkeeper.weekly-drafts
# LaunchAgent (see Scripts/install_weekly_drafts_agent.sh). Gathers real data
# (market movers, shipped work), has headless Claude write the drafts per
# marketing/PLAYBOOK.md, and commits marketing/drafts/<date>.md to main.
#
# Env overrides for testing:
#   DRAFTS_DATE=test-run   write to marketing/drafts/test-run.md
#   NO_COMMIT=1            generate but don't commit/push
#
set -u
# launchd does not inherit the login shell PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"
REPO="/Users/brevin/Developer/Inkwell Keeper"
LOG="$HOME/Library/Logs/inkwellkeeper-weekly-drafts.log"
DATE="${DRAFTS_DATE:-$(date +%Y-%m-%d)}"
OUT="marketing/drafts/$DATE.md"

mkdir -p "$(dirname "$LOG")"
exec >> "$LOG" 2>&1
echo "=== run started $(date) ==="

cd "$REPO" || { echo "repo not found"; exit 1; }
git pull --rebase --quiet || echo "warn: git pull failed, continuing with local tree"

if [ -f "$OUT" ]; then
    echo "drafts for $DATE already exist — skipping"
    exit 0
fi

MARKET=$(python3 Scripts/market_report.py --days 7 --top 5 2>&1) || MARKET="MARKET REPORT FAILED — draft without market numbers and say so."
SHIPPED=$(git log --oneline --since="1 week ago" | head -25)

PROMPT="You are the weekly marketing-drafts writer for Ink Well Keeper, a free iOS Disney Lorcana collection tracker built by solo dev Brevin. Read marketing/PLAYBOOK.md in the current directory and follow it exactly — voice, content pillars, the rotation rules, per-platform formats, standing rules.

First, read the last 2-3 editions in marketing/drafts/ and pick this week's PRIMARY pillar per the playbook's rotation section: the market report must not lead two weeks in a row, and collection tracking / feature spotlights / collector tips / build-in-public should each get their turn leading. State the chosen primary pillar and why at the top of the document.

Use ONLY this data for numbers and claims. Feature claims must come from the playbook's topic bank, marketing/3.1/RELEASE_NOTES.md, or the git log — never invent prices or features:

=== MARKET REPORT (from our own pricing backend) ===
$MARKET

=== SHIPPED THIS WEEK (git log) ===
$SHIPPED

Write the complete weekly drafts markdown document: a title with today's date, the week's angle and pillars used, then sections for: X/Twitter Monday post (a thread or single post leading with the primary pillar), X/Twitter midweek post (a lighter single post from a different pillar — feature screenshot or a chart-worthy mover), Reddit r/Lorcana post (value-first, one app mention at the end), two TikTok script outlines covering two different pillars (hook/beats/CTA, 20-40s), and an Instagram/Threads caption with share-card suggestion. If market numbers appear anywhere, include the eyeball-the-numbers warning (big % swings can be thin-market blips — lead with credible movers, quarantine suspicious ones); when the market report is not the primary pillar, keep it to one short secondary slot or drop it.

Output ONLY the markdown document. No preamble, no commentary."

mkdir -p marketing/drafts
claude -p "$PROMPT" --allowedTools "Read Glob" > "$OUT.tmp" &
CLAUDE_PID=$!
for _ in $(seq 1 90); do
    kill -0 "$CLAUDE_PID" 2>/dev/null || break
    sleep 10
done
if kill -0 "$CLAUDE_PID" 2>/dev/null; then
    kill "$CLAUDE_PID"
    echo "claude timed out after 15 minutes"
fi
wait "$CLAUDE_PID" 2>/dev/null

if [ -s "$OUT.tmp" ] && grep -q "^#" "$OUT.tmp"; then
    mv "$OUT.tmp" "$OUT"
    echo "drafts generated: $OUT"
else
    # Fallback: commit the raw data so Monday still delivers something useful
    rm -f "$OUT.tmp"
    {
        echo "# Weekly Marketing Data — $DATE"
        echo
        echo "> Draft generation failed this week — raw data below; write posts manually per marketing/PLAYBOOK.md."
        echo
        echo '```'
        echo "$MARKET"
        echo '```'
        echo
        echo "## Shipped this week"
        echo '```'
        echo "$SHIPPED"
        echo '```'
    } > "$OUT"
    echo "claude output invalid — wrote data-only fallback"
fi

if [ "${NO_COMMIT:-0}" = "1" ]; then
    echo "NO_COMMIT set — leaving $OUT uncommitted"
    exit 0
fi

git add "$OUT" && git commit -q -m "Weekly marketing drafts $DATE" && git push -q \
    && echo "committed and pushed" \
    || echo "ERROR: commit/push failed — drafts are in $OUT locally"

echo "=== run finished $(date) ==="
