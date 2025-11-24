import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var collectionManager = CollectionManager()
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var showOnboarding = false
    @State private var showBulkImport = false
    @State private var showWhatsNew = false

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

            StatsView()
                .environmentObject(collectionManager)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(4)

            WishlistView()
                .environmentObject(collectionManager)
                .tabItem {
                    Label("Wishlist", systemImage: "star.fill")
                }
                .tag(5)

            SettingsView()
                .environmentObject(collectionManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(6)

            SupportView()
                .tabItem {
                    Label("Support", systemImage: "heart.fill")
                }
                .tag(7)
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
        .onAppear {
            collectionManager.setModelContext(modelContext)
            checkOnboardingStatus()
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

