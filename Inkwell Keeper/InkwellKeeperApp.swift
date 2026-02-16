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
    init() {
        // Initialize optimized image cache on app launch
        _ = ImageCache.shared

        // Configure RevenueCat
        TipJarManager.shared.configure()

        // Check subscription status on launch
        SubscriptionManager.shared.checkSubscriptionStatus()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [CollectedCard.self, CardSet.self, CollectionStats.self, PriceHistory.self, Deck.self, DeckCard.self])
    }
}
