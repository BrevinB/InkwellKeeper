//
//  SettingsView.swift
//  Inkwell Keeper
//
//  Settings and About screen
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var collectionManager: CollectionManager

    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    @State private var showingPrivacyPolicy = false
    @State private var showingDisclaimer = false
    @State private var showingSupport = false
    @State private var showingDeleteConfirmation = false
    @State private var showingTipJar = false
    @State private var showingWhatsNew = false

    // Debug options
    @State private var showingAddSomeConfirmation = false
    @State private var showingAddMoreConfirmation = false
    @State private var showingAddAllConfirmation = false
    @State private var isAddingCards = false
    @State private var addCardsProgress: String = ""

    var body: some View {
        navigationWrapper {
            List {
                // App Info Section
                appInfoSection

                // Collection Stats Section
                statsSection

                // Legal Section
                legalSection

                // Help & Feedback Section
                feedbackSection

                // Support Development Section
                tipJarSection

                // Data Management Section
                dataSection

                // Debug Section (for testing)
                #if DEBUG
                debugSection
                #endif

                // Community Code Policy Section
                communityCodeSection

                // About Section
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showingDisclaimer) {
                DisclaimerView()
            }
            .sheet(isPresented: $showingTipJar) {
                TipJarView()
            }
            .sheet(isPresented: $showingWhatsNew) {
                WhatsNewView()
            }
            .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    deleteAllUserData()
                }
            } message: {
                Text("This will permanently delete all your collected cards, wishlist, decks, and all associated data. This action cannot be undone.")
            }
            .alert("Add Some Cards?", isPresented: $showingAddSomeConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Add 50 Cards") {
                    addDebugCards(count: 50)
                }
            } message: {
                Text("This will add 50 random cards to your collection for testing.")
            }
            .alert("Add More Cards?", isPresented: $showingAddMoreConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Add 200 Cards") {
                    addDebugCards(count: 200)
                }
            } message: {
                Text("This will add 200 random cards to your collection for testing.")
            }
            .alert("Add All Cards?", isPresented: $showingAddAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Add All") {
                    addAllDebugCards()
                }
            } message: {
                Text("This will add ALL available cards to your collection. This may take a moment.")
            }
        }
    }

    // MARK: - Sections

    private var appInfoSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ink Well Keeper")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Unofficial Lorcana Collection Tracker")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // App icon placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaGold.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.title)
                            .foregroundColor(.lorcanaGold)
                    )
            }

            HStack {
                Text("Version")
                Spacer()
                Text("\(appVersion) (\(buildNumber))")
                    .foregroundColor(.gray)
            }

            Button(action: { showingWhatsNew = true }) {
                HStack {
                    Label("What's New", systemImage: "sparkles")
                        .foregroundColor(.primary)

                    Spacer()

                    if WhatsNewManager.shared.shouldShowWhatsNew {
                        Circle()
                            .fill(Color.lorcanaGold)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }

    private var statsSection: some View {
        Section("Collection") {
            HStack {
                Label("Total Cards", systemImage: "rectangle.stack.fill")
                Spacer()
                Text("\(collectionManager.collectedCards.count)")
                    .foregroundColor(.lorcanaGold)
                    .fontWeight(.semibold)
            }

            HStack {
                Label("Wishlist", systemImage: "heart.fill")
                Spacer()
                Text("\(collectionManager.wishlistCards.count)")
                    .foregroundColor(.lorcanaGold)
                    .fontWeight(.semibold)
            }

            HStack {
                Label("Total Value", systemImage: "dollarsign.circle.fill")
                Spacer()
                Text(totalCollectionValue)
                    .foregroundColor(.lorcanaGold)
                    .fontWeight(.semibold)
            }
        }
    }

    private var legalSection: some View {
        Section("Legal") {
            Button(action: { showingDisclaimer = true }) {
                Label("Disclaimer", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.primary)
            }

            Button(action: { showingPrivacyPolicy = true }) {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
                    .foregroundColor(.primary)
            }

            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                Label("Terms of Use", systemImage: "doc.text.fill")
            }
        }
    }

    private var feedbackSection: some View {
        Section("Help & Feedback") {
            Link(destination: URL(string: "mailto:brevbot2@gmail.com?subject=Ink%20Well%20Keeper%20Support")!) {
                Label("Contact Support", systemImage: "envelope.fill")
            }

            Link(destination: URL(string: "mailto:brevbot2@gmail.com?subject=Ink%20Well%20Keeper%20-%20Issue%20Report")!) {
                Label("Report an Issue", systemImage: "exclamationmark.bubble.fill")
            }

            Button(action: requestReview) {
                Label("Rate App", systemImage: "star.fill")
                    .foregroundColor(.primary)
            }

            Button(action: shareApp) {
                Label("Share App", systemImage: "square.and.arrow.up.fill")
                    .foregroundColor(.primary)
            }
        }
    }

    private var tipJarSection: some View {
        Section {
            Button(action: { showingTipJar = true }) {
                HStack {
                    Label("Support Development", systemImage: "heart.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        } footer: {
            Text("Ink Well Keeper is free with no ads. Consider leaving a tip to support development!")
                .font(.caption)
        }
    }

    private var dataSection: some View {
        Section("Data Management") {
            Button(action: {
                Task {
                    await collectionManager.refreshAllPrices()
                }
            }) {
                Label("Refresh All Prices", systemImage: "arrow.clockwise")
                    .foregroundColor(.primary)
            }

            Button(action: {
                // Clear cache
            }) {
                Label("Clear Image Cache", systemImage: "trash.fill")
                    .foregroundColor(.primary)
            }

            Button(action: {
                resetOnboarding()
            }) {
                Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                    .foregroundColor(.primary)
            }

            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Label("Delete All Data", systemImage: "trash.fill")
                    .foregroundColor(.red)
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Debug Options") {
            if isAddingCards {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text(addCardsProgress)
                        .foregroundColor(.gray)
                }
            } else {
                Button(action: {
                    showingAddSomeConfirmation = true
                }) {
                    Label("Add Some Cards (50)", systemImage: "plus.rectangle.on.rectangle")
                        .foregroundColor(.orange)
                }

                Button(action: {
                    showingAddMoreConfirmation = true
                }) {
                    Label("Add More Cards (200)", systemImage: "plus.rectangle.fill.on.rectangle.fill")
                        .foregroundColor(.orange)
                }

                Button(action: {
                    showingAddAllConfirmation = true
                }) {
                    Label("Add All Cards", systemImage: "rectangle.stack.fill.badge.plus")
                        .foregroundColor(.orange)
                }
            }
        }
    }
    #endif

    // MARK: - Actions

    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    private var communityCodeSection: some View {
        Section("Legal Attribution") {
            VStack(alignment: .leading, spacing: 16) {
                // Main policy statement
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.lorcanaGold)
                        Text("Community Code Policy")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }

                    Text("This app uses trademarks and/or copyrights associated with Disney Lorcana TCG, under Ravensburger's Community Code Policy.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Divider()
                    .background(Color.gray.opacity(0.3))

                // Required disclaimers
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Official Disclaimer")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }

                    Text("This app is not published, endorsed, or specifically approved by Disney or Ravensburger.")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("The developer is expressly prohibited from charging you to use or access this content.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Divider()
                    .background(Color.gray.opacity(0.3))

                // Links
                VStack(alignment: .leading, spacing: 8) {
                    Link(destination: URL(string: "https://www.disneylorcana.com/")!) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.lorcanaGold)
                            Text("Disney Lorcana Official Website")
                                .font(.caption)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                        }
                    }

                    Link(destination: URL(string: "https://cdn.ravensburger.com/lorcana/community-code-en")!) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.lorcanaGold)
                            Text("Community Code Policy Document")
                                .font(.caption)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ink Well Keeper is an unofficial, fan-made collection tracking app for Disney Lorcana.")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text("This app is not affiliated with, endorsed by, or sponsored by Disney or Ravensburger.")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text("All card images, names, and game elements are property of their respective owners.")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text("Made with ❤️ for the Lorcana community")
                    .font(.caption)
                    .foregroundColor(.lorcanaGold)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Helper Methods

    private var totalCollectionValue: String {
        let total = collectionManager.collectedCards.compactMap { $0.price }.reduce(0, +)
        return String(format: "$%.2f", total)
    }

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private func shareApp() {
        let shareText = "Check out Ink Well Keeper - a collection tracker for Disney Lorcana!"
        let appURL = URL(string: "https://apps.apple.com/app/inkwell-keeper/id123456789")! // Update with real URL

        let activityVC = UIActivityViewController(
            activityItems: [shareText, appURL],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func deleteAllUserData() {
        Task {
            await collectionManager.deleteAllData()
        }
    }

    #if DEBUG
    private func addDebugCards(count: Int) {
        isAddingCards = true
        addCardsProgress = "Adding cards..."

        Task {
            let allCards = SetsDataManager.shared.getAllCards()
            let shuffledCards = allCards.shuffled()
            let cardsToAdd = Array(shuffledCards.prefix(count))

            for (index, card) in cardsToAdd.enumerated() {
                await MainActor.run {
                    addCardsProgress = "Adding card \(index + 1) of \(cardsToAdd.count)..."
                }
                collectionManager.addCard(card, quantity: 1)
            }

            await MainActor.run {
                isAddingCards = false
                addCardsProgress = ""
            }
        }
    }

    private func addAllDebugCards() {
        isAddingCards = true
        addCardsProgress = "Adding all cards..."

        Task {
            let allCards = SetsDataManager.shared.getAllCards()

            for (index, card) in allCards.enumerated() {
                if index % 50 == 0 {
                    await MainActor.run {
                        addCardsProgress = "Adding card \(index + 1) of \(allCards.count)..."
                    }
                }
                collectionManager.addCard(card, quantity: 1)
            }

            await MainActor.run {
                isAddingCards = false
                addCardsProgress = ""
            }
        }
    }
    #endif

    @ViewBuilder
    private func navigationWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            content()
        } else {
            NavigationView {
                content()
            }
        }
    }
}

// MARK: - Disclaimer View

struct DisclaimerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("⚠️ Important Disclaimer")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)

                    disclaimerText

                    copyrightNotice

                    fairUseStatement

                    liabilityDisclaimer
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var disclaimerText: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unofficial Application")
                .font(.headline)

            Text("""
Ink Well Keeper is an unofficial, fan-made application and is not affiliated with, endorsed by, or sponsored by The Walt Disney Company or Ravensburger AG.

This app is provided for informational and organizational purposes only to help fans track and manage their personal Disney Lorcana trading card collections.
""")
            .font(.body)
        }
    }

    private var copyrightNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Intellectual Property")
                .font(.headline)

            Text("""
Disney Lorcana is a trademark of The Walt Disney Company. All card images, character names, artwork, game mechanics, and related intellectual property are owned by The Walt Disney Company and Ravensburger AG.

All trademarks, service marks, trade names, product names, and logos are the property of their respective owners.
""")
            .font(.body)
        }
    }

    private var fairUseStatement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fair Use")
                .font(.headline)

            Text("""
This app uses card data and information under the doctrine of fair use for the purpose of:
• Personal collection organization
• Educational reference
• Commentary and criticism
• Transformative use (collection tracking tool)

No copyright infringement is intended. This app does not compete with official Disney Lorcana products or services.
""")
            .font(.body)
        }
    }

    private var liabilityDisclaimer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Liability")
                .font(.headline)

            Text("""
Ink Well Keeper is provided "as is" without warranties of any kind. The developers are not responsible for:
• Accuracy of card data or pricing information
• Loss of data
• Any damages arising from use of this app

Pricing information is estimated and may not reflect actual market values.
""")
            .font(.body)
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.gray)

                    introSection
                    dataCollectionSection
                    cameraPermissionSection
                    dataStorageSection
                    thirdPartySection
                    userRightsSection
                    contactSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Introduction")
                .font(.headline)

            Text("""
Ink Well Keeper ("we", "our", or "the app") is committed to protecting your privacy. This Privacy Policy explains how we handle your information when you use our Disney Lorcana collection tracking application.
""")
            .font(.body)
        }
    }

    private var dataCollectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data We Collect")
                .font(.headline)

            Text("""
We do NOT collect, transmit, or store any personal information. All data remains on your device:

• Card collection data (stored locally on your device)
• Wishlist data (stored locally on your device)
• App preferences (stored locally on your device)
• Scanned card images (processed locally, not stored)

We do not require account creation or login.
""")
            .font(.body)
        }
    }

    private var cameraPermissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Permission")
                .font(.headline)

            Text("""
The app requests camera access to enable card scanning features. Camera access is:

• Only used when you explicitly scan cards
• Images are processed locally on your device
• No images are uploaded or transmitted
• No images are permanently stored
• You can revoke this permission anytime in iOS Settings
""")
            .font(.body)
        }
    }

    private var dataStorageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Storage")
                .font(.headline)

            Text("""
All your collection data is stored locally on your device using Apple's SwiftData framework. Your data is:

• Stored only on your device
• Not synced to cloud servers
• Not accessible to us or third parties
• Removed if you delete the app
""")
            .font(.body)
        }
    }

    private var thirdPartySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Third-Party Services")
                .font(.headline)

            Text("""
This app may access third-party websites for:

• Card price estimates (TCGPlayer, eBay)
• Purchase links (affiliate links)

When you click external links, you leave our app and are subject to those websites' privacy policies. We do not control or monitor these external sites.

Note: Affiliate links may earn us a small commission at no cost to you. No personal data is shared with affiliate partners.
""")
            .font(.body)
        }
    }

    private var userRightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Rights")
                .font(.headline)

            Text("""
Since all data is stored locally on your device, you have complete control:

• Export your collection anytime
• Delete your data by uninstalling the app
• No data requests needed (we don't have your data)
• No tracking or analytics
""")
            .font(.body)
        }
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact Us")
                .font(.headline)

            Text("""
If you have questions about this Privacy Policy, contact us at:

Email: brevbot2@gmail.com

Changes to this policy will be posted in the app and reflected in the "Last Updated" date above.
""")
            .font(.body)
        }
    }
}

import StoreKit

#Preview {
    SettingsView()
        .environmentObject(CollectionManager())
}
