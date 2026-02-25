# Inkwell Keeper – Code Review and Action Plan

This document captures a thorough review of the repository and a prioritized, actionable checklist to work through.

## Overview

- Inkwell Keeper is a SwiftUI iOS app for tracking Disney Lorcana collections with OCR scanning, set browsing, deck building (AI‑assisted), pricing, wishlist, stats, and imports.
- Storage: SwiftData (`@Model`) for user data; static set JSON bundled; images cached locally.
- Services: Pricing (eBay/TCGPlayer + estimation), AI (OpenAI streaming via CloudKit‑fetched key), CloudKit key fetch, importers, data migration, affiliate links.

## What’s Working Well

- Clear modular boundaries (Services, Models, Views, Components, Data, Extensions).
- Strong domain modeling: `LorcanaCard`, `CardVariant`, `CardRarity`, deck models, reprint grouping, variant-aware image URLs.
- OCR/scan pipeline is robust with practical UX (auto/pause/resume, focus UI, throttling).
- AI deck features: streaming, good prompt design, color‑constraint enforcement, fuzzy/fallback matching.
- Pricing: in‑memory cache + `UserDefaults` cache, confidence scoring, rate‑limit handling, affiliate link generation.
- Data migration: multi‑strategy matching, backup/restore, clear result metrics.
- Image caching: tuned `URLCache`, prefetching, `CachedAsyncImage`.
- Docs: TestFlight/App Store checklists, privacy template, affiliate setup, legal disclaimers.

## High‑Priority Fixes (Build Blockers)

- [ ] Replace invalid imports `internal import AVFoundation` with `import AVFoundation`
  - Files: `ViewModels/CameraManager.swift`, `Components/CameraPreview.swift`, `Views/ScannerView.swift`
- [ ] Align `DataMigrationService` to current `CollectedCard` non‑optional fields
  - Examples of incorrect optionals: `collected.name ??` / `collected.cardId ??` → properties are non‑optional per `Models/SwiftDataModels.swift`.
- [ ] Fix migration map resource loading
  - `Bundle.main.url(forResource: path, ...)` should not pass a full path. Use: `url(forResource: "migration_map", withExtension: "json", subdirectory: "Inkwell Keeper/Data")` (or adjust to actual bundle folder).
- [ ] Ensure every `TabView` item in `ContentView.swift` has a unique `.tag(...)`
  - Current selection binding relies on tags; several tabs lack tags.

## Security & Compliance

- [ ] Remove hardcoded eBay App ID from `PricingService.getEbayAPIKey()`; fetch via `CloudKitKeyService` (like OpenAI) or secure config.
- [ ] Prefer private CloudKit (or server) for key distribution; avoid public DB exposure for secrets.
- [ ] Reassess TCGPlayer web‑scraping; prefer official API. If scraping remains, gate behind config and handle ToS/ATS.

## Reliability & Error Handling

- [ ] Replace `print` with `os.Logger` (categories + levels). Guard verbose logs with a debug flag.
- [ ] Remove heavy per‑entity debug dumps (e.g., printing all cards) in production paths.
- [ ] Add context to catch blocks currently swallowing errors (e.g., `CollectionManager` delete/clear paths) and surface actionable UI errors where user flow fails.

## Pricing Providers

- [ ] Update eBay Finding API parameters: use official condition IDs and correct filters; consider Browse API + OAuth for durability.
- [ ] Add timeouts/retry/backoff across providers, and cap `pricingCache` size with LRU + TTL.

## Performance

- [ ] Add max size + eviction to `PricingService.pricingCache` and `PriceCache` (UserDefaults TTL is present but no global size control).
- [ ] Annotate UI‑state managers with `@MainActor` (e.g., `CollectionManager`, `RulesAssistantService`, `AIDeckService`) to simplify thread hops.
- [ ] Centralize magic constants (scan thresholds, cache durations, eBay category IDs, etc.) into a `Config`.

## Architecture & Code Quality

- [ ] Introduce lightweight DI for services (init injection into view models) to improve testability (instead of strict singletons).
- [ ] Normalize resource lookup strategy in `LorcanaCardExtensions.localImageUrl()`; compute once which subdirectory exists and avoid probing/log spam.
- [ ] Prefer `uniqueId` as primary matching key where available for durability across reprints; document where/why name+set matching is used.

## Networking

- [ ] OpenAI streaming: add `Accept: text/event-stream`, set reasonable `timeoutInterval`, and basic retry for transient failures.
- [ ] Consider a dedicated `URLSession` (custom cache/timeouts) for API calls; reserve `URLSession.shared` for basic fetches.

## UX & Accessibility

- [ ] Offer theme toggle or respect system appearance (currently forces dark mode); validate contrast (gold on dark) meets WCAG AA.
- [ ] Ensure all tab items and important controls have accessibility labels/hints.
- [ ] Localize user‑facing strings in major flows (scanner errors, settings labels, AI notes).
- [ ] Validate sheet stacking/dismissal order for onboarding → import → what’s new.

## Testing

Add a small test target and prioritize pure function tests:

- [ ] Import parsing across formats (`ImportService`: CSV, text, Dreamborn, LorcanaHQ).
- [ ] AI deck parsing: `[DECKLIST]` block detection and line regex.
- [ ] Deck validation/statistics (`DeckModels`).
- [ ] Search normalization + grouping (`SetsDataManager.searchCards` / `groupCards`).
- [ ] Migration matching on fixtures (uniqueId, name+set+variant fallbacks).
- [ ] Pricing estimation heuristics and cache behavior.

## Housekeeping

- [ ] Add a top‑level `README.md` (build steps, secrets/config, feature overview, ATS/review notes).
- [ ] Exclude runtime backups and large local artifacts from Git (e.g., `Inkwell Keeper/Data/backups/**`, environment folders) via `.gitignore`.

## Suggested Implementation Order

1) Build fixes
- [ ] Replace invalid imports in camera files
- [ ] Add missing `.tag(...)` values in `ContentView.swift`
- [ ] Correct `DataMigrationService` optionals and fix bundle resource lookup

2) Secrets and providers
- [ ] Remove eBay key from source; use CloudKit fetch with proper error states
- [ ] Gate TCGPlayer scraping; prefer official API when keys configured

3) Logging and errors
- [ ] Introduce `os.Logger` + debug flag; trim verbose prints
- [ ] Improve error surfaces where flows can fail (import, pricing refresh, migration)

4) Performance and robustness
- [ ] Add LRU + TTL to in‑memory `pricingCache`; expose simple cache stats in debug view
- [ ] Add `@MainActor` to stateful services; centralize constants in a `Config`

5) Tests
- [ ] Add a test target and cover parsers, validators, and migration matching

6) Polish
- [ ] Theme/accessibility/localization passes
- [ ] README and `.gitignore` updates

## Notable File Pointers

- Navigation & tabs: `Inkwell Keeper/ContentView.swift`
- Camera & OCR: `ViewModels/CameraManager.swift`, `Components/CameraPreview.swift`, `Views/ScannerView.swift`
- Models: `Models/LorcanaCard.swift`, `Models/CardRarity.swift`, `Models/SwiftDataModels.swift`
- Data manager: `Data/SetsDataManager.swift`
- Pricing: `Services/PricingService.swift`, `Services/AffiliateService.swift`
- AI deckbuilder: `Services/AIDeckService.swift`, `Services/OpenAIService.swift`
- Rules assistant: `Services/RulesAssistantService.swift`, `Services/CloudKitKeyService.swift`
- Images: `Services/ImageCache.swift`, `Extensions/LorcanaCardExtensions.swift`
- Import: `Services/ImportService.swift`
- Migration: `Services/DataMigrationService.swift`
- Settings & legal: `Views/SettingsView.swift`, policy/checklists in root markdown files

---

If you want, I can start by patching the build blockers (imports, `TabView` tags, migration resource lookup) and set up a baseline logger. Let me know and I’ll take the first pass.
