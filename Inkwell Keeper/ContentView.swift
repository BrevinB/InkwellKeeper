import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var collectionManager = CollectionManager()
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CollectionView()
                .environmentObject(collectionManager)
                .tabItem {
                    Image(systemName: "square.grid.3x3.fill")
                    Text("Collection")
                }
                .tag(0)
            
            ScannerView()
                .environmentObject(collectionManager)
                .tabItem {
                    Image(systemName: "viewfinder")
                    Text("Scan")
                }
                .tag(1)
            
            SetsView()
                .environmentObject(collectionManager)
                .tabItem {
                    Image(systemName: "books.vertical.fill")
                    Text("Sets")
                }
                .tag(2)

            DecksView()
                .environmentObject(collectionManager)
                .tabItem {
                    Image(systemName: "rectangle.stack.fill")
                    Text("Decks")
                }
                .tag(3)

            StatsView()
                .environmentObject(collectionManager)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
                .tag(4)

            WishlistView()
                .environmentObject(collectionManager)
                .tabItem {
                    Image(systemName: "star.fill")
                    Text("Wishlist")
                }
                .tag(5)
        }
        .accentColor(.lorcanaGold)
        .preferredColorScheme(.dark)
        .onAppear {
            collectionManager.setModelContext(modelContext)
        }
    }
}

