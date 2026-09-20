# Ink Well Keeper

An iOS app for collectors of the **Disney Lorcana** trading card game: scan your cards with the
camera, track what you own across every set and variant, and see what the collection is worth.

📱 **[Download on the App Store](https://apps.apple.com/us/app/ink-well-keeper/id6754206379)** · 🌐 [inkwellkeeper.app](https://inkwellkeeper.app/)

## Features

- **Camera card scanning** — recognizes cards from the live camera using the Vision framework
- **Full set coverage** — every card, including enchanted, promo, and variant printings
- **Collection value** — current market pricing, with charts showing how value moves over time
- **iCloud sync** — the collection follows you across devices via CloudKit
- **Wishlist and deck tracking** — plan what to chase next

## Tech

| Area | Stack |
|---|---|
| UI | SwiftUI |
| Card recognition | Vision, CoreImage, AVFoundation |
| Persistence & sync | SwiftData, CloudKit |
| Charts | Swift Charts |
| Monetization | StoreKit 2, RevenueCat |
| Analytics | TelemetryDeck |
| Tests | Swift Testing |
| CI / quality | Xcode Cloud (`ci_scripts/`), SwiftLint |

## Repository layout

```
Inkwell Keeper/        iOS app source
Inkwell KeeperTests/   Swift Testing suite
Scripts/, *.py         Card data & image pipeline (pulls from lorcanajson, compresses art)
android/               Early Android port
ci_scripts/            Xcode Cloud build hooks
docs/                  Universal Links and supporting documentation
```

## Card data pipeline

Card metadata and artwork are not committed by hand — a set of Python scripts pulls from
public Lorcana data sources, maps enchanted printings back to their base cards, downloads and
compresses artwork, and emits the JSON the app ships with. See `download_lorcanajson.py`
and `update_card_data.py` as the entry points.

## Notes

This repository is published to show how the app is built. It is not intended to be built and
redistributed — the App Store release is the supported way to use Ink Well Keeper.
