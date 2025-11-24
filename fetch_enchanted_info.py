#!/usr/bin/env python3
import urllib.request
import json

# Fetch Into the Inklands cards
url = "https://api.lorcast.com/v0/sets/ITI/cards"
with urllib.request.urlopen(url) as response:
    data = json.loads(response.read())

# Find Chernabog cards
chernabog_cards = [c for c in data if 'chernabog' in c.get('name', '').lower() and 'evildoer' in c.get('name', '').lower()]

print(f"Found {len(chernabog_cards)} Chernabog - Evildoer cards:\n")

for card in chernabog_cards:
    print(f"Name: {card.get('name')}")
    print(f"Collector Number: {card.get('collector_number')}")
    print(f"Rarity: {card.get('rarity')}")
    print(f"Set ID: {card.get('set_id')}")
    print(f"Image URL: {card.get('image_uris', {}).get('digital', {}).get('normal', 'N/A')}")
    print("-" * 80)
