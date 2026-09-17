import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var collectionManager = CollectionManager()
    @StateObject private var deckManager = DeckManager()
    @Environment(\.modelContext) private var modelContext
    @State private var router = DeepLinkRouter()
    @State private var selectedTab = 0
    @State private var showOnboarding = false
    @State private var showBulkImport = false
    @State private var showWhatsNew = false

    // Deep-link presentation state
    @State private var deckImportCode: String?
    @State private var deckImportName = ""
    @State private var deepLinkedCard: LorcanaCard?

    var body: some View {
        TabView(selection: $selectedTab) {
            primaryTabs
            overflowTabs
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.lorcanaGold)
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            CloudSyncOverlay()
        }
        .onAppear {
            collectionManager.setModelContext(modelContext)
            deckManager.loadDecks(context: modelContext)
            checkOnboardingStatus()
            ReviewManager.shared.recordAppLaunch()
            Analytics.send(.screenViewed(name: Self.tabName(for: selectedTab)))
            #if DEBUG
            // Filming rig: `simctl launch … -deeplink "inkwellkeeper://…"` navigates
            // straight to a screen without the SpringBoard confirmation dialog.
            // Deferred so the card catalog is loaded before the route resolves.
            if let spec = UserDefaults.standard.string(forKey: "deeplink"),
               let url = URL(string: spec) {
                print("IWK-FILM: deeplink arg -> \(url)")
                Task {
                    // Wait for the card catalog before resolving the route.
                    for _ in 0..<60 where !SetsDataManager.shared.isDataLoaded {
                        try? await Task.sleep(for: .milliseconds(250))
                    }
                    try? await Task.sleep(for: .milliseconds(500))
                    let handled = router.handle(url)
                    print("IWK-FILM: handled=\(handled) loaded=\(SetsDataManager.shared.isDataLoaded)")
                }
            } else {
                print("IWK-FILM: no deeplink arg; args=\(ProcessInfo.processInfo.arguments)")
            }
            #endif
        }
        .onChange(of: selectedTab) { _, newTab in
            Analytics.send(.screenViewed(name: Self.tabName(for: newTab)))
        }
        .onOpenURL { router.handle($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { router.handle($0) }
        .onChange(of: router.pendingRoute) { _, route in
            if let route {
                handleDeepLink(route)
                router.pendingRoute = nil
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(onImportTap: {
                // Delay showing import to allow onboarding to dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showBulkImport = true
                }
            })
        }
        .sheet(isPresented: $showBulkImport) {
            BulkImportView()
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView()
        }
        .sheet(item: $deepLinkedCard) { card in
            CollectionCardDetailView(
                card: card,
                isPresented: Binding(
                    get: { deepLinkedCard != nil },
                    set: { if !$0 { deepLinkedCard = nil } }
                )
            )
            .environmentObject(collectionManager)
        }
        .alert("Import Deck", isPresented: Binding(
            get: { deckImportCode != nil },
            set: { if !$0 { deckImportCode = nil } }
        )) {
            Button("Cancel", role: .cancel) { deckImportCode = nil }
            Button("Import") {
                if let code = deckImportCode {
                    _ = deckManager.importDeck(from: code)
                    selectedTab = 3
                }
                deckImportCode = nil
            }
        } message: {
            Text("Add “\(deckImportName)” to your decks?")
        }
    }

    /// Routes a parsed deep link to the right tab and presentation.
    private func handleDeepLink(_ route: DeepLinkRoute) {
        switch route {
        case let .deck(code):
            // Only prompt when the code is valid and decodable.
            if let preview = deckManager.previewShareCode(code) {
                deckImportName = preview.name
                deckImportCode = code
            }
        case let .card(id):
            if let card = SetsDataManager.shared.getAllCards().first(where: { $0.id == id }) {
                selectedTab = 0
                deepLinkedCard = card
            }
        case .set:
            selectedTab = route.tab
        }
    }

    /// The four that lead the tab bar. iOS shows the first four plus a More
    /// list once there are more than five, so the core loop leads: collect,
    /// scan, build, and what it is worth.
    ///
    /// `value:` carries the same identifier the old `.tag()` did, so
    /// DeepLinkRouter.tab and Analytics' tabName(for:) keep working unchanged.
    @TabContentBuilder<Int>
    private var primaryTabs: some TabContent<Int> {
        Tab("Collection", systemImage: "square.grid.3x3.fill", value: 0) {
            CollectionView(selectedTab: $selectedTab)
                .environmentObject(collectionManager)
        }

        Tab("Scan", systemImage: "viewfinder", value: 1) {
            ScannerView(isActive: Binding(
                get: { selectedTab == 1 },
                set: { _ in }
            ))
            .environmentObject(collectionManager)
        }

        Tab("Decks", systemImage: "rectangle.stack.fill", value: 3) {
            DecksView()
                .environmentObject(collectionManager)
        }

        Tab("Stats", systemImage: "chart.bar.fill", value: 4) {
            StatsView()
                .environmentObject(collectionManager)
        }
    }

    /// Everything the system collects into More on iPhone, and lists below the
    /// primary tabs in the iPad sidebar.
    @TabContentBuilder<Int>
    private var overflowTabs: some TabContent<Int> {
        Tab("Sets", systemImage: "books.vertical.fill", value: 2) {
            SetsView()
                .environmentObject(collectionManager)
        }

        Tab("Trades", systemImage: "arrow.left.arrow.right", value: 10) {
            TradeCalculatorView()
                .environmentObject(collectionManager)
        }

        Tab("Play", systemImage: "gamecontroller.fill", value: 9) {
            LoreCounterView()
        }

        Tab("Wishlist", systemImage: "star.fill", value: 5) {
            WishlistView()
                .environmentObject(collectionManager)
        }

        Tab("Settings", systemImage: "gear", value: 6) {
            SettingsView()
                .environmentObject(collectionManager)
        }

        Tab("Support", systemImage: "heart.fill", value: 7) {
            SupportView()
        }

        Tab("Rules", systemImage: "book.circle", value: 8) {
            RulesAssistantView()
        }
    }

    /// Maps a tab's selection tag to a human-readable screen name for analytics.
    private static func tabName(for tag: Int) -> String {
        switch tag {
        case 0: "Collection"
        case 1: "Scan"
        case 2: "Sets"
        case 3: "Decks"
        case 4: "Stats"
        case 5: "Wishlist"
        case 6: "Settings"
        case 7: "Support"
        case 8: "Rules"
        case 9: "Play"
        case 10: "Trades"
        default: "Tab\(tag)"
        }
    }

    private func checkOnboardingStatus() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            // Delay showing onboarding slightly to allow the app to fully load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showOnboarding = true
            }
        } else {
            // For existing users, check if we should show What's New
            checkWhatsNewStatus()
        }
    }

    private func checkWhatsNewStatus() {
        // Show What's New if this is a new version
        if WhatsNewManager.shared.shouldShowWhatsNew {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showWhatsNew = true
            }
        }
    }
}
