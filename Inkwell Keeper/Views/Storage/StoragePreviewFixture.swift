//
//  StoragePreviewFixture.swift
//  Inkwell Keeper
//
//  In-memory collection with a filled binder and trove, for SwiftUI previews of the
//  storage screens. Uses real bundled card images (The First Chapter).
//

#if DEBUG
import SwiftUI
import SwiftData

@MainActor
struct StoragePreviewFixture {
    /// One fixture for every preview. Previews can rebuild their body many times, and a
    /// fixture discarded mid-flight tears down a store its background tasks still use.
    static let shared = Self()

    let modelContainer: ModelContainer
    let collectionManager = CollectionManager()
    let storageManager = StorageManager()
    let binder: StorageContainer
    let trove: StorageContainer

    init() {
        // A preview can't do anything useful without its store, so failing loudly is right.
        // swiftlint:disable:next force_try
        modelContainer = try! ModelContainer(
            for: CollectedCard.self, CardSet.self, CollectionStats.self, PriceHistory.self,
            Deck.self, DeckCard.self, StorageContainer.self, StoredCard.self,
            configurations: ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true)
        )
        let context = modelContainer.mainContext
        let rarities: [CardRarity] = [.common, .uncommon, .rare, .superRare, .legendary]

        for number in 1...40 {
            let card = CollectedCard(
                cardId: "TFC-\(number)",
                name: "Card \(number)",
                cost: number % 8 + 1,
                type: "Character",
                rarity: rarities[number % rarities.count],
                setName: "The First Chapter",
                imageUrl: "",
                price: Double(number % 7) * 1.25,
                quantity: number.isMultiple(of: 5) ? 3 : 1,
                variant: number.isMultiple(of: 6) ? .foil : .normal,
                uniqueId: String(format: "TFC-%03d", number),
                cardNumber: number
            )
            context.insert(card)
        }
        try? context.save()

        collectionManager.setModelContext(context)
        storageManager.setModelContext(context)

        binder = storageManager.createContainer(name: "Main Binder", kind: .binder) {
            $0.coverColor = .ruby
            $0.cover = .starlight
            $0.sheetCount = 4
        } ?? StorageContainer(name: "Main Binder", kind: .binder)
        trove = storageManager.createContainer(name: "Amber Trove", kind: .trove) {
            $0.coverColor = .amber
            $0.cover = .leather
        } ?? StorageContainer(name: "Amber Trove", kind: .trove)

        // A fuller bookcase: binders of different colors, finishes and thicknesses, and one of each box.
        let extras: [(String, StorageKind, StorageCoverColor, StorageCoverStyle, Int)] = [
            ("Winterspell Master Set", .binder, .sapphire, .leather, 50),
            ("Trade Binder", .binder, .emerald, .classic, 12),
            ("Enchanteds", .binder, .ivory, .holofoil, 20),
            ("Amber Steel", .deckBox, .midnight, .classic, 0),
            ("Bulk Commons", .storageBox, .steel, .classic, 0),
            ("Loose Cards", .bulkBin, .amethyst, .classic, 0)
        ]
        for (name, kind, color, style, sheets) in extras {
            _ = storageManager.createContainer(name: name, kind: kind) {
                $0.coverColor = color
                $0.cover = style
                if sheets > 0 { $0.sheetCount = sheets }
            }
        }

        let cards = collectionManager.collectedCards
        storageManager.autoFill(binder, with: Array(cards.prefix(24)), order: .setNumber, setOrder: [:])
        for card in cards.suffix(10) {
            storageManager.store(card, quantity: 2, in: trove)
        }
    }
}

#Preview("Binder – iPhone") {
    let fixture = StoragePreviewFixture.shared
    NavigationStack {
        BinderView(container: fixture.binder, focusSlot: 4)
    }
    .environment(fixture.collectionManager)
    .environment(fixture.storageManager)
    .modelContainer(fixture.modelContainer)
    .preferredColorScheme(.dark)
}

#Preview("Binder – Spread", traits: .landscapeLeft) {
    let fixture = StoragePreviewFixture.shared
    NavigationStack {
        BinderView(container: fixture.binder, focusSlot: 12)
    }
    .environment(fixture.collectionManager)
    .environment(fixture.storageManager)
    .modelContainer(fixture.modelContainer)
    .preferredColorScheme(.dark)
}

#Preview("Box") {
    let fixture = StoragePreviewFixture.shared
    NavigationStack {
        BoxView(container: fixture.trove)
    }
    .environment(fixture.collectionManager)
    .environment(fixture.storageManager)
    .modelContainer(fixture.modelContainer)
    .preferredColorScheme(.dark)
}

/// Supplies the namespace the shelf needs.
private struct ShelfPreviewHost: View {
    let fixture: StoragePreviewFixture
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            StorageShelfView(unsortedCount: 17, showUnsortedOnly: .constant(false), transitionNamespace: namespace)
                .padding()
                .frame(maxHeight: .infinity, alignment: .top)
                .background(LorcanaBackground())
        }
        .environment(fixture.collectionManager)
        .environment(fixture.storageManager)
        .modelContainer(fixture.modelContainer)
        .preferredColorScheme(.dark)
    }
}

#Preview("Bookshelf") {
    let fixture = StoragePreviewFixture.shared
    BookshelfView()
        .environment(fixture.collectionManager)
        .environment(fixture.storageManager)
        .modelContainer(fixture.modelContainer)
        .preferredColorScheme(.dark)
}

#Preview("Shelf") {
    ShelfPreviewHost(fixture: StoragePreviewFixture.shared)
}

#Preview("Editor") {
    let fixture = StoragePreviewFixture.shared
    ContainerEditorSheet(container: nil)
        .environment(fixture.storageManager)
        .modelContainer(fixture.modelContainer)
        .preferredColorScheme(.dark)
}
#endif
