#!/usr/bin/env python3
"""
Check for missing starter decks.
Compares local starter deck data against released sets to detect gaps.

Usage:
    python Scripts/check_starter_decks.py

For GitHub Actions (outputs in a format suitable for issue creation):
    python Scripts/check_starter_decks.py --github-action
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple
from datetime import datetime

# Configuration
DATA_DIR = Path(__file__).parent.parent / "Inkwell Keeper" / "Data"

# Sets that should have starter decks (main sets only, not promos/special)
# Format: set_id -> expected number of starter decks
SETS_WITH_STARTER_DECKS = {
    "the_first_chapter": 3,
    "rise_of_the_floodborn": 3,
    "into_the_inklands": 3,
    "ursulas_return": 3,
    "shimmering_skies": 3,
    "azurite_sea": 2,
    "archazias_island": 2,
    "reign_of_jafar": 2,
    "whispers_in_the_well": 2,
    "winterspell": 2,  # Expected when released
}

# Sets that don't have starter decks (promos, special sets)
SETS_WITHOUT_STARTER_DECKS = [
    "fabled",
    "promo_set_1",
    "promo_set_2",
    "challenge_promo",
    "d23_collection",
]


def load_sets_data() -> Dict:
    """Load the sets.json file."""
    sets_file = DATA_DIR / "sets.json"
    if sets_file.exists():
        with open(sets_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {"sets": []}


def is_set_released(release_date_str: str) -> bool:
    """Check if a set has been released based on its release date."""
    if not release_date_str:
        return False
    try:
        release_date = datetime.strptime(release_date_str, "%Y-%m-%d")
        return release_date <= datetime.now()
    except ValueError:
        return False


def load_starter_decks() -> Dict:
    """Load the starter_decks.json file."""
    decks_file = DATA_DIR / "starter_decks.json"
    if decks_file.exists():
        with open(decks_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {"starterDecks": []}


def get_starter_deck_counts() -> Dict[str, int]:
    """Get count of starter decks per set."""
    decks_data = load_starter_decks()
    counts = {}

    for deck in decks_data.get("starterDecks", []):
        set_name = deck.get("setName", "")
        counts[set_name] = counts.get(set_name, 0) + 1

    return counts


def check_for_missing_decks(github_action: bool = False) -> Tuple[bool, str]:
    """
    Check for missing starter decks.

    Returns:
        Tuple of (has_missing, report_string)
    """
    report_lines = []
    has_missing = False
    missing_decks = []
    incomplete_sets = []

    # Load data
    sets_data = load_sets_data()
    deck_counts = get_starter_deck_counts()

    # Build set name to ID mapping
    set_name_to_id = {}
    set_id_to_name = {}
    released_sets = {}

    for s in sets_data.get("sets", []):
        set_name_to_id[s["name"]] = s["id"]
        set_id_to_name[s["id"]] = s["name"]
        # Check both isReleased flag AND actual release date
        is_released = s.get("isReleased", False) and is_set_released(s.get("releaseDate", ""))
        released_sets[s["id"]] = is_released

    report_lines.append("# Starter Deck Update Check")
    report_lines.append("")
    report_lines.append(f"**Local Data:** {DATA_DIR}")
    report_lines.append(f"**Check Date:** {datetime.now().strftime('%Y-%m-%d')}")
    report_lines.append("")

    # Check each set that should have starter decks
    report_lines.append("## Starter Deck Coverage")
    report_lines.append("")
    report_lines.append("| Set | Expected | Local | Status |")
    report_lines.append("|-----|----------|-------|--------|")

    for set_id, expected_count in SETS_WITH_STARTER_DECKS.items():
        set_name = set_id_to_name.get(set_id, set_id)
        local_count = deck_counts.get(set_name, 0)
        is_released = released_sets.get(set_id, False)

        if local_count == 0 and is_released:
            has_missing = True
            missing_decks.append({
                "set_id": set_id,
                "set_name": set_name,
                "expected": expected_count
            })
            report_lines.append(f"| {set_name} | {expected_count} | {local_count} | **Missing** |")
        elif local_count < expected_count and is_released:
            has_missing = True
            incomplete_sets.append({
                "set_id": set_id,
                "set_name": set_name,
                "expected": expected_count,
                "actual": local_count
            })
            report_lines.append(f"| {set_name} | {expected_count} | {local_count} | **Incomplete** |")
        elif not is_released:
            report_lines.append(f"| {set_name} | {expected_count} | {local_count} | Not Released |")
        else:
            report_lines.append(f"| {set_name} | {expected_count} | {local_count} | ✓ Complete |")

    report_lines.append("")

    # Check for any new sets not in our expected list
    new_sets = []
    for s in sets_data.get("sets", []):
        set_id = s["id"]
        if (set_id not in SETS_WITH_STARTER_DECKS and
            set_id not in SETS_WITHOUT_STARTER_DECKS and
            s.get("isReleased", False)):
            new_sets.append(s["name"])

    if new_sets:
        report_lines.append("## New Sets Detected")
        report_lines.append("")
        report_lines.append("The following released sets are not in the starter deck tracking list:")
        for name in new_sets:
            report_lines.append(f"- {name}")
        report_lines.append("")
        report_lines.append("Please update `check_starter_decks.py` to include these sets.")
        report_lines.append("")

    # Summary
    if has_missing:
        report_lines.append("## Action Required")
        report_lines.append("")

        if missing_decks:
            report_lines.append("### Sets Missing All Starter Decks")
            for item in missing_decks:
                report_lines.append(f"- **{item['set_name']}**: Need {item['expected']} deck(s)")
            report_lines.append("")

        if incomplete_sets:
            report_lines.append("### Sets with Incomplete Starter Decks")
            for item in incomplete_sets:
                report_lines.append(f"- **{item['set_name']}**: Have {item['actual']}/{item['expected']} decks")
            report_lines.append("")

        report_lines.append("### Recommended Actions")
        report_lines.append("1. Search for official starter deck lists on [Mushu Report](https://wiki.mushureport.com/) or [Lorcana Player](https://lorcanaplayer.com/)")
        report_lines.append("2. Add missing decks to `starter_decks.json`")
        report_lines.append("3. Update app version and release")
    else:
        report_lines.append("## Status: Up to Date")
        report_lines.append("")
        report_lines.append("All released sets have complete starter deck coverage.")

    report = "\n".join(report_lines)
    return has_missing, report


def main():
    github_action = "--github-action" in sys.argv

    has_missing, report = check_for_missing_decks(github_action)

    print(report)

    # For GitHub Actions, output to environment file
    if github_action:
        github_output = os.environ.get("GITHUB_OUTPUT", "")
        if github_output:
            with open(github_output, "a") as f:
                f.write(f"has_missing={'true' if has_missing else 'false'}\n")
                f.write(f"report<<EOF\n{report}\nEOF\n")

        sys.exit(0)

    return 0 if not has_missing else 1


if __name__ == "__main__":
    sys.exit(main())
