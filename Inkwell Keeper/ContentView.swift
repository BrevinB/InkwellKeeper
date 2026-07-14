import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var collectionManager = CollectionManager()
    @StateObject private var deckManager = DeckManager()
    @State private var syncMonitor = CloudSyncMonitor.shared
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
            CollectionView(selectedTab: $selectedTab)
                .environmentObject(collectionManager)
                .tabItem {
                    Label("Collection", systemImage: "square.grid.3x3.fill")
                }
                .tag(0)

            ScannerView(isActive: Binding(
                get: { selectedTab == 1 },
                set: { _ in }
            ))
                .environmentObject(collectionManager)
                .tabItem {
                    Label("Scan", systemImage: "viewfinder")
                }
                .tag(1)

            SetsView()
                .environmentObject(collectionManager)
                .tabItem {
                    Label("Sets", systemImage: "books.vertical.fill")
                }
                .tag(2)

            DecksView()
                .environmentObject(collectionManager)
                .tabItem {
                    Label("Decks", systemImage: "rectangle.stack.fill")
                }
                .tag(3)

            LoreCounterView()
                .tabItem {
                    Label("Play", systemImage: "gamecontroller.fill")
                }
                .tag(9)

            StatsView()
                .environmentObject(collectionManager)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }

            WishlistView()
                .environmentObject(collectionManager)
                .tabItem {
                    Label("Wishlist", systemImage: "star.fill")
                }

            SettingsView()
                .environmentObject(collectionManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            SupportView()
                .tabItem {
                    Label("Support", systemImage: "heart.fill")
                }
                .tag(7)

            RulesAssistantView()
                .tabItem {
                    Label("Rules", systemImage: "book.circle")
                }
                .tag(8)
        }
        .apply { view in
            if #available(iOS 18.0, *) {
                view.tabViewStyle(.sidebarAdaptable)
            } else {
                view
            }
        }
        .accentColor(.lorcanaGold)
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if syncMonitor.isReceivingFromCloud {
                CloudSyncBanner()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: syncMonitor.isReceivingFromCloud)
        .onAppear {
            collectionManager.setModelContext(modelContext)
            deckManager.loadDecks(context: modelContext)
            checkOnboardingStatus()
            ReviewManager.shared.recordAppLaunch()
            Analytics.send(.screenViewed(name: Self.tabName(for: selectedTab)))
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

    /// Maps a tab's selection tag to a human-readable screen name for analytics.
    private static func tabName(for tag: Int) -> String {
        switch tag {
        case 0: "Collection"
        case 1: "Scan"
        case 2: "Sets"
        case 3: "Decks"
        case 7: "Support"
        case 8: "Rules"
        case 9: "Play"
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
