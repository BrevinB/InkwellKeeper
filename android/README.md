# Inkwell Keeper for Android

Kotlin + Jetpack Compose port of the iOS app. Open `android/` in Android Studio.

The card catalog is copied at build time from `../Inkwell Keeper/Data/*.json` (no duplicate JSON in git).
User data is stored as JSON in app storage (`files/data/`). Backups use the iOS `InkwellBackup` format.

## Done
Collection (search/filters/sort/storage shelf), card detail (Normal+Foil qty, photos, purchase price,
condition, price history, buy links, share image), catalog search + add sheet, Decks (list, new/edit,
workspace builder, validation incl. Core rotation/bans/Coconut, import/export text, `IWK2:` share codes
interoperable with iOS via a Kotlin LZFSE/LZVN codec, opening hand, deck share image, build/pull into deck
box, starter decks), Scanner (CameraX + ML Kit OCR, iOS matcher port, multi-scan tray), Sets + set detail,
Wishlist, Stats (+ portfolio history, movers, cost basis — Pro-gated), Settings, Import/Export, storage
(binder page view with checklist ghosts / move / auto-fill, box view, Bookshelf), Trades, Lore counter,
Rules Assistant and AI Deck Builder / Completer / Swaps / Strategy (same prompts and post-processing as iOS),
Support, What's New, Keyword Glossary, Pricing info, onboarding, deep links.

## Setup notes
All machine-specific values go in the git-ignored `local.properties`:

| Key | What | Without it |
|-----|------|------------|
| `revenuecat.googleKey` | RevenueCat's public Google Play SDK key (`goog_...`) | Pro is locked; paywall says subscriptions aren't available |
| `ai.proxyUrl` | `AiProxyUrl` output of the lorcana-pricing-api stack (see its README) | AI screens show "AI Unavailable" (release) |
| `openai.apiKey` | **Debug builds only**, used when `ai.proxyUrl` is blank | — |

- **Pro** comes from RevenueCat — same project, entitlement (`Ink Well Keeper Pro`) and `default` offering
  as iOS. Debug builds also have a "Premium Override" switch in Settings and Support.
- **AI** goes through the proxy, which holds the OpenAI key, checks the entitlement against the RevenueCat
  app user id, and enforces the 50/25 daily limits. Release builds never contain an OpenAI key.
- **Release signing:** copy `keystore.properties.example` to `keystore.properties` and create the upload key.
  `./gradlew :app:bundleRelease` then writes a signed `app/build/outputs/bundle/release/app-release.aab`.
  Release builds are minified with R8 — smoke-test one before uploading.
- **Not ported:** iCloud sync (no Android equivalent yet), TelemetryDeck (Analytics logs to logcat),
  widgets, tip jar, Universal Links verification (needs assetlinks.json on the site).

## Build
```sh
JAVA_HOME=<JDK 17+> ./gradlew :app:testDebugUnitTest :app:assembleDebug
JAVA_HOME=<JDK 17+> ./gradlew :app:bundleRelease   # Play upload
```
