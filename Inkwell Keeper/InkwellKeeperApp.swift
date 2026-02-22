//
//  Inkwell_KeeperApp.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI
import SwiftData
import RevenueCat

@main
struct InkwellKeeperApp: App {
    let container: ModelContainer

    init() {
        // Initialize optimized image cache on app launch
        _ = ImageCache.shared

        // Configure RevenueCat
        TipJarManager.shared.configure()

        // Check subscription status on launch
        SubscriptionManager.shared.checkSubscriptionStatus()

        container = Self.makeContainer()
    }

    /// Creates the SwiftData ModelContainer without CloudKit sync.
    /// The app has CloudKit capability enabled in its entitlements, which causes SwiftData
    /// to attempt CloudKit integration by default. CloudKit requires all attributes to be
    /// optional and forbids unique constraints — neither of which matches our schema.
    /// Passing cloudKitDatabase: .none opts out entirely.
    private static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let c = try ModelContainer(
                for: CollectedCard.self, CardSet.self, CollectionStats.self,
                PriceHistory.self, Deck.self, DeckCard.self,
                configurations: config
            )
            print("✅ [ModelContainer] Opened successfully at \(config.url.path)")
            return c
        } catch {
            print("❌ [ModelContainer] Failed to open: \(error)")
        }

        // Persistent store may be corrupt from a previous failed session — delete and retry.
        let storeURL = config.url
        let fm = FileManager.default
        print("   Deleting store at: \(storeURL.path)")
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
                print("   🗑 Deleted: \(url.lastPathComponent)")
            }
        }

        do {
            let c = try ModelContainer(
                for: CollectedCard.self, CardSet.self, CollectionStats.self,
                PriceHistory.self, Deck.self, DeckCard.self,
                configurations: config
            )
            print("✅ [ModelContainer] Recovery successful — fresh store created")
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
