//
//  WhatsNewView.swift
//  Inkwell Keeper
//
//  View to display changelog and new features
//

import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentVersion: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Version history
                    ForEach(changelogEntries, id: \.version) { entry in
                        changelogSection(for: entry)
                    }
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Mark this version as seen
                        WhatsNewManager.shared.markVersionAsSeen()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            currentVersion = WhatsNewManager.shared.currentVersion
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.lorcanaGold)

            Text("What's New in Ink Well Keeper")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Version \(currentVersion)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    private func changelogSection(for entry: ChangelogEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Version header
            HStack {
                Text("Version \(entry.version)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                if entry.version == currentVersion {
                    Text("LATEST")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.lorcanaGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.lorcanaGold.opacity(0.2))
                        )
                }

                Spacer()
            }

            Text(entry.date)
                .font(.subheadline)
                .foregroundColor(.gray)

            // Features
            if !entry.features.isEmpty {
                featureGroup(title: "✨ New Features", items: entry.features, color: .green)
            }

            // Improvements
            if !entry.improvements.isEmpty {
                featureGroup(title: "🔧 Improvements", items: entry.improvements, color: .blue)
            }

            // Bug Fixes
            if !entry.bugFixes.isEmpty {
                featureGroup(title: "🐛 Bug Fixes", items: entry.bugFixes, color: .orange)
            }

            // In Progress
            if !entry.inProgress.isEmpty {
                featureGroup(title: "🚧 In Progress", items: entry.inProgress, color: .yellow)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.4))
        )
    }

    private func featureGroup(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
                .padding(.top, 8)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(color)
                        .fontWeight(.bold)

                    Text(item)
                        .font(.body)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Changelog Data

struct ChangelogEntry {
    let version: String
    let date: String
    let features: [String]
    let improvements: [String]
    let bugFixes: [String]
    let inProgress: [String]
}

// Add new versions at the top of this array
private let changelogEntries: [ChangelogEntry] = [
    ChangelogEntry(
        version: "1.4.0",
        date: "February 2026",
        features: [
            "Lore Counter - Track lore for two players with a built-in game counter, includes quick access to official rules",
            "Rules Assistant - AI-powered rules assistant that can answer questions about Lorcana rules and card interactions",
            "Multi-Card References - Attach up to 4 cards at once to ask the Rules Assistant about card interactions",
            "Interactive Foil Effect - Foil cards now feature a holographic tilt effect using your device's motion sensors"
        ],
        improvements: [
            "Updated Winterspell set with all released cards",
            "Improved Play tab UI with lore counter and rules access",
            "Enhanced LLM rules logic with comprehensive game rules coverage",
            "Card text is now used as the authoritative source for rules questions"
        ],
        bugFixes: [],
        inProgress: []
    ),
    ChangelogEntry(
        version: "1.3.0",
        date: "January 2026",
        features: [
            "Winterspell Set - Added support for the new Winterspell set with 175 cards (more coming as they're revealed)",
            "6 New Starter Decks - Added starter decks for Azurite Sea, Archazia's Island, and Reign of Jafar",
            "Automated Updates - Card data now automatically checked weekly for new cards and sets"
        ],
        improvements: [
            "All card data synced with latest from LorCast API",
            "Added Dalmatian Puppy variant cards (4a-4e) to Into the Inklands",
            "Added Mickey Mouse international promo variants (Japanese & Chinese)",
            "Updated set card counts to match official totals"
        ],
        bugFixes: [],
        inProgress: []
    ),
    ChangelogEntry(
        version: "1.2.0",
        date: "January 2026",
        features: [
            "Dynamic Export Fields - Choose exactly which fields to include in your export from 19 available options including card number, rarity, ink color, stats, price, and more",
            "Multiple Export Formats - Export to Custom CSV, Dreamborn Bulk Add, Dreamborn Collection, Lorcana HQ, or JSON Backup",
            "Variant Filtering - Filter your collection by Normal, Foil, Enchanted, Promo, or Special variants to easily track your master set progress",
            "Multi-Variant Adding - Add both Normal and Foil copies of a card at the same time instead of searching twice",
            "Collapsible Filter Bar - Filters now collapse to save screen space, with active filters shown as removable pills"
        ],
        improvements: [
            "Export now includes card collector numbers",
            "Quick export presets (Basic, Standard, Full) for fast field selection",
            "Filter bar shows count of active filters",
            "Clear All Filters button to quickly reset filters",
            "Sort option always visible even when filters collapsed",
            "Export formats show file type badges (.csv, .json)"
        ],
        bugFixes: [],
        inProgress: []
    ),
    ChangelogEntry(
        version: "1.1.0",
        date: "November 2025",
        features: [
            "DISCLAIMER: A big overhaul happened to get all the missing cards into the app, if you notice any issues with your cards they may have to be re-added. We apologize for the inconvenience",
            "Enhanced character normalization for imports - Better handling of special characters like apostrophes and ellipsis",
            "Improved image loading for newly added cards",
        ],
        improvements: [
            "Fixed set count display for reprinted cards",
            "Promo variants now correctly treated as separate cards",
            "Better matching of cards across different sets",
            "More reliable image caching and display",
            "Added enchanted, epic and iconic images",
            "Pricing has been inaccurate, until I can get TCGPlayer API access I've temporarily removed the pricing. There are still links that take you to TCGPlayer and eBay"
        ],
        bugFixes: [
            "Fixed incorrect set counts showing for collections",
            "Fixed Promo cards incorrectly matching with Normal variants",
            "Resolved import failures for cards with special characters"
        ],
        inProgress: []
    ),
    ChangelogEntry(
        version: "1.0.0",
        date: "October 2025",
        features: [
            "Track your Lorcana card collection",
            "Create and manage wishlists",
            "Scan cards using your camera",
            "Import collections from CSV files",
            "Import collection from Dreamborn",
            "Export your collection data",
            "View card prices and market data",
            "Filter and sort your collection",
            "Track collection progress by set"
        ],
        improvements: [],
        bugFixes: [],
        inProgress: []
    )
]

// MARK: - What's New Manager

class WhatsNewManager {
    static let shared = WhatsNewManager()

    private let lastSeenVersionKey = "LastSeenWhatsNewVersion"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var shouldShowWhatsNew: Bool {
        let lastSeenVersion = UserDefaults.standard.string(forKey: lastSeenVersionKey)
        return lastSeenVersion != currentVersion
    }

    func markVersionAsSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenVersionKey)
    }

    private init() {}
}

#Preview {
    WhatsNewView()
}
