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
    @State private var showingPricingInfo = false

    // Debug options
    @State private var showingAddSomeConfirmation = false
    @State private var showingAddMoreConfirmation = false
    @State private var showingAddAllConfirmation = false
    @State private var isAddingCards = false
    @State private var addCardsProgress: String = ""

    // Preferences
    @State private var preferredCurrency: String = UserDefaults.standard.string(forKey: "preferredCurrency") ?? "USD"

    var body: some View {
        NavigationStack {
            List {
                // App Info Section
                appInfoSection

                // Preferences Section
                preferencesSection

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
            .sheet(isPresented: $showingPricingInfo) {
                PricingInfoView()
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

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker("Currency", selection: $preferredCurrency) {
                Text("USD ($)").tag("USD")
                Text("EUR (\u{20AC})").tag("EUR")
            }
            .onChange(of: preferredCurrency) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "preferredCurrency")
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
            Button(action: { showingPricingInfo = true }) {
                Label("About Pricing", systemImage: "tag.fill")
                    .foregroundColor(.primary)
            }

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
            Toggle(isOn: Binding(
                get: { SubscriptionManager.shared.debugPremiumOverride },
                set: { SubscriptionManager.shared.debugPremiumOverride = $0 }
            )) {
                Label("Premium Override", systemImage: "crown.fill")
                    .foregroundStyle(.orange)
            }

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
        return PricingService.formatPrice(total)
    }

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private func shareApp() {
        let shareText = "Check out Ink Well Keeper - a collection tracker for Disney Lorcana!"
        guard let appURL = AppLinks.appStoreURL else { return }

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

Pricing information is sourced from third-party marketplaces and may not reflect actual market values. Cards without available market data will not display a price.
""")
            .font(.body)
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.title)
                        .bold()

                    Text("Last Updated: July 6, 2026")
                        .font(.caption)
                        .foregroundStyle(.gray)

                    introSection
                    collectionDataSection
                    cameraSection
                    analyticsSection
                    aiFeaturesSection
                    subscriptionsSection
                    pricingSection
                    neverDoSection
                    childrenSection
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
Ink Well Keeper ("the app") is built to keep your data yours. This policy explains what is collected, what isn't, and where your information goes.
""")
            .font(.body)
        }
    }

    private var collectionDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Collection Data")
                .font(.headline)

            Text("""
Cards, decks, wishlists, photos you attach, and stats are stored on your device. If you enable iCloud sync, this data is also stored in your private iCloud database, which only you can access — we cannot read it. Deleting the app (and the app's iCloud data in iOS Settings) removes it entirely.

We do not require account creation or login.
""")
            .font(.body)
        }
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera")
                .font(.headline)

            Text("""
The camera is used only to recognize trading cards. Recognition happens on your device; scan images are not uploaded anywhere. Photos you deliberately attach to a card stay in your collection data. You can revoke camera access anytime in iOS Settings.
""")
            .font(.body)
        }
    }

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics")
                .font(.headline)

            Text("""
The app uses TelemetryDeck, a privacy-focused analytics service, to understand which features are used (for example, "a scan happened"). Signals are anonymized before they reach TelemetryDeck; no personal identifiers, no advertising IDs, no cross-app tracking.
""")
            .font(.body)
        }
    }

    private var aiFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Features (Pro)")
                .font(.headline)

            Text("""
When you use the Rules Assistant or AI Deck Builder, the text of your question and relevant card names are sent to OpenAI to generate a response. Don't include personal information in prompts. Your collection is not uploaded wholesale.
""")
            .font(.body)
        }
    }

    private var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscriptions")
                .font(.headline)

            Text("""
Ink Well Keeper Pro purchases are processed by Apple and managed through RevenueCat, which handles subscription status using anonymous identifiers. We never see your payment details.
""")
            .font(.body)
        }
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prices & Purchase Links")
                .font(.headline)

            Text("""
Card prices come from public market data; requests contain card identifiers, not personal data. "Buy" buttons are affiliate links to third-party marketplaces (e.g. TCGplayer, Cardmarket) with their own privacy policies; the app may earn a commission at no cost to you and receives no information about your purchases.
""")
            .font(.body)
        }
    }

    private var neverDoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What We Never Do")
                .font(.headline)

            Text("""
• No ads, no ad tracking, no selling or sharing of data
• No accounts — nothing to sign up for
• No collection of names, emails, contacts, or location
""")
            .font(.body)
        }
    }

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Children")
                .font(.headline)

            Text("""
The app is rated 4+ and does not knowingly collect personal information from children.
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

Email: support@inkwellkeeper.app

Material changes will be posted in the app and at inkwellkeeper.app/privacy, and reflected in the "Last Updated" date above.
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
