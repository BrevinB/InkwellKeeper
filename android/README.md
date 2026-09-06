# Inkwell Keeper for Android

This is the native Android MVP for Ink Well Keeper. Open the `android/` directory in
Android Studio and let it use the Gradle configuration in `app/`.

## Included in the MVP

- Kotlin + Jetpack Compose UI
- Local collection, wishlist, and deck storage
- Catalog search and card details
- Remote card artwork loaded with Coil's disk cache
- Dreamborn CSV and simple text-list import/export compatible with the iOS workflows
- TCGPlayer price search from card details
- `https://inkwellkeeper.app/deck` deep-link declaration

The card catalog is copied from the iOS app's `Data/*.json` files into Android assets.
User data intentionally remains local in this phase; import/export is the bridge between
iOS and Android. Camera scanning, AI, live cross-platform sync, Google Play products,
and rich share-card rendering are phase-two work.

## Local build

```sh
ANDROID_SDK_ROOT="$ANDROID_HOME" ./gradlew :app:testDebugUnitTest :app:assembleDebug
```

The debug APK is written to `app/build/outputs/apk/debug/app-debug.apk`.
