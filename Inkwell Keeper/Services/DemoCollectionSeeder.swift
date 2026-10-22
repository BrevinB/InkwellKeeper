//
//  DemoCollectionSeeder.swift
//  Inkwell Keeper
//
//  Filming rig: fills an empty simulator store with a believable collection,
//  binders and boxes, so marketing screenshots show a lived-in app.
//
//      xcrun simctl launch <sim> co.brevinb.Inkwell-Keeper -seedDemo YES
//

#if DEBUG && targetEnvironment(simulator)
import Foundation
import SwiftData

@MainActor
enum DemoCollectionSeeder {
    /// Seeds only when asked for, into an empty collection, with no iCloud account
    /// signed in, so demo cards can never sync into a real collection.
    static func seedIfRequested(
        collectionManager: CollectionManager,
        storageManager: StorageManager,
        context: ModelContext
    ) async {
        guard UserDefaults.standard.bool(forKey: "seedDemo") else { return }
        guard FileManager.default.ubiquityIdentityToken == nil else {
            print("IWK-SEED: refused, an iCloud account is signed in")
            return
        }
        for _ in 0..<60 where !SetsDataManager.shared.isDataLoaded {
            try? await Task.sleep(for: .milliseconds(250))
        }
        guard collectionManager.collectedCards.isEmpty else {
            print("IWK-SEED: skipped, collection is not empty")
            return
        }

        let cardsBySet = seedCollection(context: context)
        collectionManager.loadCollection()
        print("IWK-SEED: seeded \(collectionManager.collectedCards.count) printings; fetching prices")

        // Prices first: storage snapshots each card's price when it is stored.
        await collectionManager.refreshAllPrices()
        storageManager.loadContainers()
        seedStorage(storageManager: storageManager, collectionManager: collectionManager, cardsBySet: cardsBySet)
        print("IWK-SEED: done")
    }

    /// Owns a different share of each set (newest sets least complete), with playsets
    /// of commons, the odd foil, and only a handful of Enchanteds and Epics.
    private static func seedCollection(context: ModelContext) -> [String: [LorcanaCard]] {
        var generator = SeededGenerator(seed: 2026)
        let data = SetsDataManager.shared
        // Main numbered sets only, oldest first; promo and event sets would make odd binders.
        let sets = data.getAllSets()
            .filter { Int($0.setNumber ?? "") != nil && !$0.isUpcoming() && data.hasLocalCards(for: $0.name) }
            .sorted { Int($0.setNumber ?? "") ?? 0 < Int($1.setNumber ?? "") ?? 0 }
        let completion: [Double] = [0.94, 0.86, 0.81, 0.77, 0.88, 0.69, 0.74, 0.64, 0.58, 0.52, 0.47, 0.41, 0.36, 0.31]
        var owned: [String: [LorcanaCard]] = [:]

        for (index, set) in sets.enumerated() {
            let share = completion[min(index, completion.count - 1)]
            for card in data.getCardsForSet(set.name) {
                let chance: Double = switch card.variant {
                case .enchanted: 0.12
                case .epic: 0.18
                case .iconic, .promo, .borderless: 0
                default: share
                }
                guard Double.random(in: 0..<1, using: &generator) < chance else { continue }

                let quantity: Int = switch card.rarity {
                case .common: Int.random(in: 1...4, using: &generator)
                case .uncommon: Int.random(in: 1...3, using: &generator)
                case .rare: Int.random(in: 1...2, using: &generator)
                default: 1
                }
                insert(card, quantity: quantity, into: context)
                owned[set.name, default: []].append(card)

                if card.variant == .normal, Double.random(in: 0..<1, using: &generator) < 0.1 {
                    let foil = card.withVariant(.foil)
                    insert(foil, quantity: 1, into: context)
                    owned[set.name, default: []].append(foil)
                }
            }
        }
        try? context.save()
        return owned
    }

    private static func insert(_ card: LorcanaCard, quantity: Int, into context: ModelContext) {
        let row = CollectedCard(
            cardId: card.id,
            name: card.name,
            cost: card.cost,
            type: card.type,
            rarity: card.rarity,
            setName: card.setName,
            cardText: card.cardText,
            imageUrl: card.imageUrl,
            price: card.price,
            quantity: quantity,
            variant: card.variant,
            inkColor: card.inkColor,
            uniqueId: card.uniqueId,
            cardNumber: card.cardNumber
        )
        // Spread "date added" over the last few months so Recent Additions looks real.
        row.dateAdded = Date.now.addingTimeInterval(-Double(abs(card.id.hashValue) % 7_776_000))
        context.insert(row)
    }

    /// A bookshelf of binders and boxes in different colours and finishes, filled from the seeded cards.
    private static func seedStorage(
        storageManager: StorageManager,
        collectionManager: CollectionManager,
        cardsBySet: [String: [LorcanaCard]]
    ) {
        let setOrder = BinderSortOrder.catalogSetOrder()
        let all = collectionManager.collectedCards
        let chase = all.filter { [.enchanted, .epic].contains($0.variant) }
        let sets = Array(cardsBySet.keys).sorted {
            Int(SetsDataManager.shared.getSet(byName: $0)?.setNumber ?? "") ?? 0
                < Int(SetsDataManager.shared.getSet(byName: $1)?.setNumber ?? "") ?? 0
        }

        // Set checklist binders for the newest and the first set.
        for (setName, color, style) in [(sets.last, StorageCoverColor.amber, StorageCoverStyle.leather),
                                        (sets.first, .sapphire, .starlight)] {
            guard let setName, let binder = storageManager.createContainer(name: setName, kind: .binder, configure: {
                $0.coverColor = color
                $0.cover = style
                $0.linkedSetName = setName
                $0.sheetCount = 14
            }) else { continue }
            storageManager.autoFill(binder, with: all.filter { $0.setName == setName }, order: .setNumber, setOrder: setOrder)
        }

        if let binder = storageManager.createContainer(name: "Enchanteds", kind: .binder, configure: {
            $0.coverColor = .ivory
            $0.cover = .holofoil
            $0.sheetCount = 6
        }) {
            storageManager.autoFill(binder, with: chase, order: .setNumber, setOrder: setOrder)
        }

        if let binder = storageManager.createContainer(name: "Trade Binder", kind: .binder, configure: {
            $0.coverColor = .emerald
            $0.cover = .classic
            $0.sheetCount = 8
        }) {
            let rares = all.filter { [.rare, .superRare, .legendary].contains($0.rarity) && $0.variant == .normal }
            storageManager.autoFill(binder, with: Array(rares.prefix(70)), order: .ink, setOrder: setOrder)
        }

        let boxes: [(String, StorageKind, StorageCoverColor, StorageCoverStyle, [CardRarity])] = [
            ("Amber Trove", .trove, .amber, .leather, [.uncommon]),
            ("Bulk Commons", .storageBox, .steel, .classic, [.common]),
            ("Loose Cards", .bulkBin, .amethyst, .classic, [.common, .uncommon])
        ]
        for (name, kind, color, style, rarities) in boxes {
            guard let box = storageManager.createContainer(name: name, kind: kind, configure: {
                $0.coverColor = color
                $0.cover = style
            }) else { continue }
            // Each store() saves, so keep boxes to a believable handful rather than everything.
            for card in all.filter({ rarities.contains($0.rarity) }).prefix(120) {
                storageManager.store(card, quantity: 2, in: box, source: "demoSeed")
            }
        }
    }
}
#endif
