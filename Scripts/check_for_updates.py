#!/usr/bin/env python3
"""
Check for Lorcana card data updates.
Compares local JSON files against the LorCast API to detect new cards and sets.

Usage:
    python Scripts/check_for_updates.py

For GitHub Actions (outputs in a format suitable for issue creation):
    python Scripts/check_for_updates.py --github-action
"""

import json
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Configuration
DATA_DIR = Path(__file__).parent.parent / "Inkwell Keeper" / "Data"
LORCAST_API_BASE = "https://api.lorcast.com/v0"
TIMEOUT = 30

# Set ID mapping: local filename -> LorCast API code
# LorCast uses numeric codes (1, 2, 3...) for main sets
SET_MAPPING = {
    "the_first_chapter": "1",
    "rise_of_the_floodborn": "2",
    "into_the_inklands": "3",
    "ursulas_return": "4",
    "shimmering_skies": "5",
    "azurite_sea": "6",
    "archazias_island": "7",
    "reign_of_jafar": "8",
    "fabled": "9",
    "whispers_in_the_well": "10",
    "winterspell": "11",
    "promo_set_1": "P1",
    "promo_set_2": "P2",
    "challenge_promo": "cp",
    "d23_collection": "D23",
}


def fetch_json(url: str) -> Optional[Dict]:
    """Fetch JSON data from a URL."""
    try:
        headers = {'User-Agent': 'InkwellKeeper/1.0'}
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code} fetching {url}", file=sys.stderr)
        return None
    except urllib.error.URLError as e:
        print(f"URL Error fetching {url}: {e.reason}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error fetching {url}: {e}", file=sys.stderr)
        return None


def get_lorcast_sets() -> List[Dict]:
    """Fetch all sets from the LorCast API."""
    url = f"{LORCAST_API_BASE}/sets"
    data = fetch_json(url)
    if data and "results" in data:
        return data["results"]
    return []


def get_lorcast_set_cards(set_code: str) -> int:
    """Get the card count for a specific set from LorCast API."""
    url = f"{LORCAST_API_BASE}/sets/{set_code}/cards"
    data = fetch_json(url)
    if data and isinstance(data, list):
        return len(data)
    return 0


def load_local_sets() -> Dict[str, Dict]:
    """Load local set data from JSON files."""
    local_sets = {}

    # Load sets.json for metadata
    sets_file = DATA_DIR / "sets.json"
    if sets_file.exists():
        with open(sets_file, 'r', encoding='utf-8') as f:
            sets_data = json.load(f)
            for s in sets_data.get("sets", []):
                local_sets[s["id"]] = {
                    "name": s["name"],
                    "setCode": s["setCode"],
                    "cardCount": s["cardCount"],
                    "actualCards": 0
                }

    # Load actual card counts from individual set files
    for json_file in DATA_DIR.glob("*.json"):
        if json_file.name in ["sets.json", "migration_map.json", "starter_decks.json", ".json"]:
            continue

        set_id = json_file.stem
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                card_count = len(data.get("cards", []))

                if set_id in local_sets:
                    local_sets[set_id]["actualCards"] = card_count
                else:
                    local_sets[set_id] = {
                        "name": data.get("setName", set_id),
                        "setCode": data.get("setCode", ""),
                        "cardCount": data.get("cardCount", 0),
                        "actualCards": card_count
                    }
        except Exception as e:
            print(f"Error reading {json_file}: {e}", file=sys.stderr)

    return local_sets


def check_for_updates(github_action: bool = False) -> Tuple[bool, str]:
    """
    Compare local data against LorCast API.

    Returns:
        Tuple of (has_updates, report_string)
    """
    report_lines = []
    has_updates = False
    new_sets = []
    updated_sets = []

    print("Fetching data from LorCast API...", file=sys.stderr)

    # Get LorCast sets
    lorcast_sets = get_lorcast_sets()
    if not lorcast_sets:
        return False, "Error: Could not fetch sets from LorCast API"

    # Load local data
    local_sets = load_local_sets()

    # Create reverse mapping: API code -> local file ID
    api_code_to_local = {v: k for k, v in SET_MAPPING.items()}

    report_lines.append("# Lorcana Card Data Update Check")
    report_lines.append("")
    report_lines.append(f"**API Source:** LorCast API ({LORCAST_API_BASE})")
    report_lines.append(f"**Local Data:** {DATA_DIR}")
    report_lines.append("")

    # Check each set from LorCast
    report_lines.append("## Set Comparison")
    report_lines.append("")
    report_lines.append("| Set | LorCast Cards | Local Cards | Difference |")
    report_lines.append("|-----|---------------|-------------|------------|")

    total_api_cards = 0
    total_local_cards = 0

    for lorcast_set in lorcast_sets:
        api_code = lorcast_set.get("code", "")
        set_name = lorcast_set.get("name", "Unknown")

        # Get card count from API for this set
        print(f"  Checking {set_name}...", file=sys.stderr)
        api_card_count = get_lorcast_set_cards(api_code)
        total_api_cards += api_card_count

        # Find matching local set using the mapping
        local_file_id = api_code_to_local.get(api_code)
        local_set = local_sets.get(local_file_id) if local_file_id else None

        if local_set:
            local_card_count = local_set["actualCards"]
            total_local_cards += local_card_count
            diff = api_card_count - local_card_count

            if diff > 0:
                has_updates = True
                updated_sets.append({
                    "name": set_name,
                    "code": api_code,
                    "diff": diff,
                    "api_count": api_card_count,
                    "local_count": local_card_count
                })
                report_lines.append(f"| {set_name} | {api_card_count} | {local_card_count} | **+{diff}** |")
            elif diff < 0:
                report_lines.append(f"| {set_name} | {api_card_count} | {local_card_count} | {diff} |")
            else:
                report_lines.append(f"| {set_name} | {api_card_count} | {local_card_count} | 0 |")
        else:
            # New set not in local data
            has_updates = True
            new_sets.append({
                "name": set_name,
                "code": api_code,
                "card_count": api_card_count
            })
            report_lines.append(f"| **{set_name}** | {api_card_count} | **Missing** | **+{api_card_count}** |")

    report_lines.append("")
    report_lines.append(f"**Total:** LorCast has {total_api_cards} cards, Local has {total_local_cards} cards")
    report_lines.append("")

    # Summary section
    if has_updates:
        report_lines.append("## Updates Available")
        report_lines.append("")

        if new_sets:
            report_lines.append("### New Sets Detected")
            for s in new_sets:
                report_lines.append(f"- **{s['name']}** ({s['code']}): {s['card_count']} cards")
            report_lines.append("")

        if updated_sets:
            report_lines.append("### Sets with New Cards")
            for s in updated_sets:
                report_lines.append(f"- **{s['name']}** ({s['code']}): +{s['diff']} new cards ({s['local_count']} -> {s['api_count']})")
            report_lines.append("")

        report_lines.append("### Recommended Actions")
        report_lines.append("1. Run the card download script to update local data")
        report_lines.append("2. Review new cards for any data quality issues")
        report_lines.append("3. Update app version and release")
    else:
        report_lines.append("## Status: Up to Date")
        report_lines.append("")
        report_lines.append("Local data matches the LorCast API. No updates needed.")

    report = "\n".join(report_lines)

    return has_updates, report


def main():
    github_action = "--github-action" in sys.argv

    has_updates, report = check_for_updates(github_action)

    print(report)

    # For GitHub Actions, output to environment file
    if github_action:
        github_output = os.environ.get("GITHUB_OUTPUT", "")
        if github_output:
            with open(github_output, "a") as f:
                f.write(f"has_updates={'true' if has_updates else 'false'}\n")
                # Escape newlines for multiline output
                escaped_report = report.replace("%", "%25").replace("\n", "%0A").replace("\r", "%0D")
                f.write(f"report<<EOF\n{report}\nEOF\n")

        # Exit with code 0 for no updates, 1 for updates (useful for CI)
        sys.exit(0)

    return 0 if not has_updates else 1


if __name__ == "__main__":
    sys.exit(main())
