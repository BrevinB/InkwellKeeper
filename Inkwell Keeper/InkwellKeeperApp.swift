//
//  Inkwell_KeeperApp.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI
import SwiftData
import RevenueCat
import TelemetryDeck

@main
struct InkwellKeeperApp: App {
    let container: ModelContainer

    init() {
        let config = TelemetryDeck.Config(appID: "F297E779-0C2D-4BBB-837D-71EB70FC8F18")
        TelemetryDeck.initialize(config: config)
        // Initialize optimized image cache on app launch
        _ = ImageCache.shared

        // Configure RevenueCat
        TipJarManager.shared.configure()

        // Check subscription status on launch
        SubscriptionManager.shared.checkSubscriptionStatus()

        // Refresh deck-construction rules (rotation + banned lists) from CloudKit
        DeckRulesService.shared.refresh()

        container = Self.makeContainer()
    }

    /// Creates the SwiftData ModelContainer with iCloud (CloudKit) sync enabled.
    /// All @Model types are CloudKit-compliant: no unique constraints, every non-optional
    /// attribute has a default value, and all relationships are optional. With no iCloud
    /// account signed in, SwiftData automatically falls back to local-only storage.
    private static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.co.brevinb.Inkwell-Keeper")
        )

        do {
            let c = try ModelContainer(
                for: CollectedCard.self, CardSet.self, CollectionStats.self,
                PriceHistory.self, Deck.self, DeckCard.self,
                configurations: config
            )
            return c
        } catch {
        }

        // Persistent store may be corrupt from a previous failed session — delete and retry.
        let storeURL = config.url
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
        }

        do {
            let c = try ModelContainer(
                for: CollectedCard.self, CardSet.self, CollectionStats.self,
                PriceHistory.self, Deck.self, DeckCard.self,
                configurations: config
            )
            return c
        } catch {
            fatalError("❌ [ModelContainer] Cannot create container even after store deletion: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
