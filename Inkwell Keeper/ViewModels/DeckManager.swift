//
//  DeckManager.swift
//  Inkwell Keeper
//
//  Manages deck creation, editing, and validation
//

import SwiftUI
import Combine
import SwiftData
import Foundation
import CoreData

class DeckManager: ObservableObject {
    var modelContext: ModelContext?
    @Published var decks: [Deck] = []

    /// Observer token for CloudKit remote-change notifications.
    private var remoteChangeObserver: NSObjectProtocol?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        if let context = modelContext {
            loadDecks(context: context)
        }
    }

    deinit {
        if let remoteChangeObserver {
            NotificationCenter.default.removeObserver(remoteChangeObserver)
        }
    }

    // MARK: - Load Decks
    func loadDecks(context: ModelContext) {
        self.modelContext = context
        let descriptor = FetchDescriptor<Deck>(sortBy: [SortDescriptor(\.lastModified, order: .reverse)])

        do {
            decks = try context.fetch(descriptor)
        } catch {
            decks = []
        }

        startObservingRemoteChanges()
    }

    /// CloudKit imports changes on a background context and posts
    /// `.NSPersistentStoreRemoteChange`. Our `decks` array is populated by manual fetches,
    /// so we re-merge duplicate deck cards + reload whenever synced data lands.
    private func startObservingRemoteChanges() {
        guard remoteChangeObserver == nil, let context = modelContext else { return }
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.mergeDuplicateDeckCards()
                self.loadDecks(context: context)
            }
        }
    }

    /// Collapses duplicate `DeckCard` rows within a deck that appear when two devices each add
    /// the same card to the same deck while offline and CloudKit later merges both. Rows are the
    /// "same card" when they share (uniqueId, else name||setName) + variant. Mirrors the merge
    /// logic in `CollectionManager.mergeDuplicateCollectedCards`.
    func mergeDuplicateDeckCards() {
        guard let context = modelContext else { return }

        do {
            let allDecks = try context.fetch(FetchDescriptor<Deck>())

            var didChange = false
            for deck in allDecks {
                let cards = deck.cards ?? []
                guard cards.count > 1 else { continue }

                var groups: [String: [DeckCard]] = [:]
                for card in cards {
                    let identity = (card.uniqueId?.isEmpty == false)
                        ? card.uniqueId!
                        : "\(card.name)||\(card.setName)"
                    let key = "\(identity)|\(card.variant)"
                    groups[key, default: []].append(card)
                }

                let maxCopies = deck.deckFormat.maxCopiesPerCard
                for (_, rows) in groups where rows.count > 1 {
                    // Keep the earliest-added row; fold the rest into it.
                    let sorted = rows.sorted { $0.cardId < $1.cardId }
                    let survivor = sorted[0]
                    for dup in sorted.dropFirst() {
                        survivor.quantity = min(max(survivor.quantity, dup.quantity), maxCopies)
                        if survivor.price == nil { survivor.price = dup.price }
                        deck.cards?.removeAll { $0 === dup }
                        context.delete(dup)
                        didChange = true
                    }
                }
            }

            if didChange {
                try context.save()
            }
        } catch {
            // Non-fatal — duplicates are cosmetic and will be retried on the next sync.
        }
    }

    // MARK: - Create Deck
    func createDeck(
        name: String,
        description: String = "",
        format: DeckFormat = .infinityConstructed,
        inkColors: [InkColor] = [],
        archetype: DeckArchetype? = nil
    ) -> Deck {
        guard let context = modelContext else {
            return Deck(name: name)
        }

        let deck = Deck(
            name: name,
            description: description,
            format: format,
            inkColors: inkColors,
            archetype: archetype
        )

        context.insert(deck)

        do {
            try context.save()
            Analytics.send(.deckCreated)
            loadDecks(context: context)
        } catch {
            // Handle error silently
        }

        return deck
    }

    // MARK: - Delete Deck
    func deleteDeck(_ deck: Deck) {
        guard let context = modelContext else { return }

        context.delete(deck)

        do {
            try context.save()
            Analytics.send(.deckDeleted)
            loadDecks(context: context)
        } catch {
            // Handle error silently
        }
    }

    // MARK: - Update Deck
    func updateDeck(_ deck: Deck) {
        guard let context = modelContext else { return }

        deck.lastModified = Date()

        do {
            try context.save()
        } catch {
            // Handle error silently
        }
    }

    // MARK: - Add Card to Deck
    func addCard(_ card: LorcanaCard, to deck: Deck, quantity: Int = 1) {
        guard let context = modelContext else { return }

        var cardToUpdate: DeckCard?

        // Check if card already exists in deck
        if let existingCard = (deck.cards ?? []).first(where: { $0.cardId == card.id }) {
            // Increment quantity (respecting max copies)
            let newQuantity = min(existingCard.quantity + quantity, deck.deckFormat.maxCopiesPerCard)
            existingCard.quantity = newQuantity
            cardToUpdate = existingCard
        } else {
            // Add new card
            let deckCard = DeckCard(from: card, quantity: min(quantity, deck.deckFormat.maxCopiesPerCard))
            if deck.cards == nil { deck.cards = [] }
            deck.cards?.append(deckCard)
            context.insert(deckCard)
            cardToUpdate = deckCard
        }

        deck.lastModified = Date()

        do {
            try context.save()
            Analytics.send(.deckCardAdded)

            // Fetch price for the card in background
            if let deckCard = cardToUpdate {
                Task {
                    await updateCardPrice(deckCard)
                }
            }
        } catch {
            // Handle error silently
        }
    }

    // MARK: - Update Card Price
    private func updateCardPrice(_ deckCard: DeckCard) async {
        let card = deckCard.toLorcanaCard
        do {
            if let pricing = try await PricingService.shared.getPricing(for: card) {
                let averagePrice = pricing.prices.map { $0.price }.reduce(0, +) / Double(pricing.prices.count)

                await MainActor.run {
                    deckCard.price = averagePrice
                    try? modelContext?.save()
                }
            }
        } catch {
            // Pricing failed - card will remain with nil/0 price
        }
    }

    // MARK: - Remove Card from Deck
    func removeCard(_ deckCard: DeckCard, from deck: Deck) {
        guard let context = modelContext else { return }

        if let index = (deck.cards ?? []).firstIndex(where: { $0.cardId == deckCard.cardId }),
           let removedCard = deck.cards?.remove(at: index) {
            context.delete(removedCard)
            deck.lastModified = Date()

            do {
                try context.save()
                Analytics.send(.deckCardRemoved)
            } catch {
                // Handle error silently
            }
        }
    }

    // MARK: - Update Card Quantity
    func updateCardQuantity(_ deckCard: DeckCard, in deck: Deck, quantity: Int) {
        guard let context = modelContext else { return }
        let maxCopies = deck.deckFormat.maxCopiesPerCard

        if quantity <= 0 {
            removeCard(deckCard, from: deck)
        } else {
            deckCard.quantity = min(quantity, maxCopies)
            deck.lastModified = Date()

            do {
                try context.save()
            } catch {
                // Handle error silently
            }
        }
    }

    // MARK: - Duplicate Deck
    func duplicateDeck(_ deck: Deck) -> Deck {
        let newDeck = createDeck(
            name: "\(deck.name) (Copy)",
            description: deck.deckDescription,
            format: deck.deckFormat,
            inkColors: deck.deckInkColors,
            archetype: deck.deckArchetype
        )

        // Copy all cards
        for deckCard in deck.cards ?? [] {
            let card = deckCard.toLorcanaCard
            addCard(card, to: newDeck, quantity: deckCard.quantity)
        }

        return newDeck
    }

    // MARK: - Validate Deck
    func validateDeck(_ deck: Deck) -> DeckValidation {
        return DeckValidation.validate(deck)
    }

    // MARK: - Calculate Statistics
    func calculateStatistics(for deck: Deck, collectionManager: CollectionManager) -> DeckStatistics {
        return DeckStatistics.calculate(for: deck, collectionManager: collectionManager)
    }

    // MARK: - Export Deck
    func exportDeckList(_ deck: Deck) -> String {
        var output = ""

        // Header
        output += "Deck: \(deck.name)\n"
        output += "Format: \(deck.deckFormat.rawValue)\n"
        if !deck.deckInkColors.isEmpty {
            output += "Colors: \(deck.deckInkColors.map { $0.rawValue }.joined(separator: ", "))\n"
        }
        if let archetype = deck.deckArchetype {
            output += "Archetype: \(archetype.rawValue)\n"
        }
        output += "Cards: \(deck.totalCards)\n"
        output += "\n"

        // Group cards by cost
        let cardsByCost = Dictionary(grouping: deck.cards ?? []) { $0.cost }
        let sortedCosts = cardsByCost.keys.sorted()

        for cost in sortedCosts {
            let cards = cardsByCost[cost]!.sorted { $0.name < $1.name }
            for card in cards {
                output += "\(card.quantity)x \(card.name) (\(card.setName))\n"
            }
        }

        output += "\n"
        output += "Exported from Ink Well Keeper\n"

        return output
    }

    // MARK: - Get Missing Cards
    func getMissingCards(for deck: Deck, collectionManager: CollectionManager) -> [(card: DeckCard, needed: Int)] {
        var missing: [(card: DeckCard, needed: Int)] = []

        for deckCard in deck.cards ?? [] {
            // Try ID match first, then fallback to name match
            var ownedQuantity = collectionManager.getCollectedQuantity(for: deckCard.cardId)
            if ownedQuantity == 0 {
                ownedQuantity = collectionManager.getCollectedQuantityByName(
                    deckCard.name,
                    setName: deckCard.setName,
                    variant: deckCard.cardVariant
                )
            }

            let neededQuantity = deckCard.quantity
            let missingCount = max(0, neededQuantity - ownedQuantity)

            if missingCount > 0 {
                missing.append((card: deckCard, needed: missingCount))
            }
        }

        return missing.sorted { $0.card.name < $1.card.name }
    }

    // MARK: - Community Text Deck List

    /// The deck as community-format text (`4 Elsa - Snow Queen` per line) — the format
    /// Dreamborn and other Lorcana sites exchange, so lists paste cleanly between apps.
    func exportCommunityDeckList(_ deck: Deck) -> String {
        DeckListTextCodec.export(deck)
    }

    /// Imports a community-format text deck list as a new deck. Returns `nil` when no line
    /// resolves to a known card; otherwise the deck plus any lines that couldn't be matched.
    func importDeck(fromText text: String, name: String) -> (deck: Deck, unmatched: [DeckListTextCodec.UnmatchedLine])? {
        guard let context = modelContext else { return nil }

        let result = DeckListTextCodec.parse(text, cards: SetsDataManager.shared.getAllCards())
        guard !result.entries.isEmpty else { return nil }

        let deck = Deck(name: name, format: .infinityConstructed)
        context.insert(deck)

        for entry in result.entries {
            let deckCard = DeckCard(from: entry.card, quantity: entry.quantity)
            if deck.cards == nil { deck.cards = [] }
            deck.cards?.append(deckCard)
            context.insert(deckCard)
        }

        do {
            try context.save()
            Analytics.send(.deckImported)
            updateDeckColorsFromCards(deck)
            loadDecks(context: context)
            return (deck, result.unmatched)
        } catch {
            return nil
        }
    }

    // MARK: - Share Deck Code

    /// Legacy (`IWK:`) share payload: every card carries a full snapshot. Kept so codes shared
    /// from older versions still import; new codes are always the compact `IWK2:` format.
    struct ShareableDeck: Codable {
        let name: String
        let description: String
        let format: String
        let inkColors: [String]
        let archetype: String?
        let cards: [ShareableCard]
    }

    struct ShareableCard: Codable {
        let cardId: String
        let name: String
        let cost: Int
        let type: String
        let rarity: String
        let setName: String
        let imageUrl: String
        let inkColor: String?
        let inkwell: Bool
        let quantity: Int
        let variant: String
    }

    /// Compact (`IWK2:`) share payload: cards travel as id + variant + quantity only and are
    /// resolved against the bundled card database on import. Card ids are deterministic across
    /// installs, so this stays small enough to fit in a scannable QR code — the legacy format's
    /// full snapshots overflowed `AppLinks.maxDeckCodeLengthForQR` for any realistic deck.
    struct CompactShareableDeck: Codable {
        let name: String
        let description: String
        let format: String
        let inkColors: [String]
        let archetype: String?
        let cards: [CompactShareableCard]

        // Single-letter wire keys keep the encoded payload small.
        enum CodingKeys: String, CodingKey {
            case name = "n"
            case description = "d"
            case format = "f"
            case inkColors = "i"
            case archetype = "a"
            case cards = "c"
        }
    }

    struct CompactShareableCard: Codable {
        let id: String
        /// Variant rawValue; `nil` means normal.
        let variant: String?
        let quantity: Int

        enum CodingKeys: String, CodingKey {
            case id
            case variant = "v"
            case quantity = "q"
        }
    }

    private static let sharePrefixV2 = "IWK2:"
    private static let sharePrefixV1 = "IWK:"

    /// A share code decoded to the point where it can be previewed or imported, regardless of
    /// which on-the-wire format it arrived in.
    private struct DecodedSharedDeck {
        let name: String
        let description: String
        let format: String
        let inkColors: [String]
        let archetype: String?
        /// Fully resolved cards ready to become `DeckCard`s.
        let cards: [(card: LorcanaCard, quantity: Int)]
        /// Total including cards that couldn't be resolved locally (used for previews).
        let totalCards: Int
    }

    func generateShareCode(for deck: Deck) -> String? {
        let shareable = CompactShareableDeck(
            name: deck.name,
            description: deck.deckDescription,
            format: deck.format,
            inkColors: deck.inkColors,
            archetype: deck.archetype,
            cards: (deck.cards ?? []).map { card in
                CompactShareableCard(
                    id: card.cardId,
                    variant: card.cardVariant == .normal ? nil : card.variant,
                    quantity: card.quantity
                )
            }
        )

        guard let jsonData = try? JSONEncoder().encode(shareable),
              let compressed = try? (jsonData as NSData).compressed(using: .lzfse) else {
            return nil
        }

        return Self.sharePrefixV2 + Self.base64URLEncode(compressed as Data)
    }

    /// Decodes a share code just far enough to preview it (name + card count) without importing.
    /// Returns `nil` if the code has no recognized prefix or can't be decoded.
    func previewShareCode(_ shareCode: String) -> (name: String, totalCards: Int)? {
        guard let decoded = decodeShareCode(shareCode) else { return nil }
        return (decoded.name, decoded.totalCards)
    }

    func importDeck(from shareCode: String) -> Deck? {
        guard let context = modelContext else { return nil }
        guard let decoded = decodeShareCode(shareCode) else { return nil }

        let format = DeckFormat(rawValue: decoded.format) ?? .infinityConstructed
        let inkColors = decoded.inkColors.compactMap { InkColor.fromString($0) }
        let archetype = decoded.archetype.flatMap { DeckArchetype(rawValue: $0) }

        let deck = Deck(
            name: decoded.name,
            description: decoded.description,
            format: format,
            inkColors: inkColors,
            archetype: archetype
        )

        context.insert(deck)

        for entry in decoded.cards {
            let deckCard = DeckCard(from: entry.card, quantity: entry.quantity)
            if deck.cards == nil { deck.cards = [] }
            deck.cards?.append(deckCard)
            context.insert(deckCard)
        }

        do {
            try context.save()
            Analytics.send(.deckImported)
            loadDecks(context: context)
            return deck
        } catch {
            return nil
        }
    }

    /// Pulls a share code out of whatever the user pasted: a raw `IWK2:`/`IWK:` code, a
    /// `https://inkwellkeeper.app/deck?code=…` link, or an `inkwellkeeper://deck?code=…` deep
    /// link. Returns `nil` when the text is none of those (e.g. a text deck list).
    static func extractShareCode(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix(sharePrefixV2) || trimmed.hasPrefix(sharePrefixV1) {
            return trimmed
        }

        if trimmed.lowercased().hasPrefix("http") || trimmed.lowercased().hasPrefix("\(AppLinks.scheme)://"),
           let components = URLComponents(string: trimmed),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
           code.hasPrefix(sharePrefixV2) || code.hasPrefix(sharePrefixV1) {
            return code
        }

        return nil
    }

    /// Parses either share-code format into a resolved intermediate. Compact codes are looked up
    /// in the bundled card database; cards this app version doesn't know (e.g. a set it predates)
    /// are dropped from the import but still counted in `totalCards`. Accepts a raw code or a
    /// share link containing one.
    private func decodeShareCode(_ shareCode: String) -> DecodedSharedDeck? {
        guard let code = Self.extractShareCode(from: shareCode) else { return nil }

        if code.hasPrefix(Self.sharePrefixV2) {
            guard let data = Self.base64URLDecode(String(code.dropFirst(Self.sharePrefixV2.count))),
                  let decompressed = try? (data as NSData).decompressed(using: .lzfse),
                  let shareable = try? JSONDecoder().decode(CompactShareableDeck.self, from: decompressed as Data) else {
                return nil
            }

            let cardsById = Dictionary(
                SetsDataManager.shared.getAllCards().map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            var resolved: [(card: LorcanaCard, quantity: Int)] = []
            for compact in shareable.cards {
                guard let dbCard = cardsById[compact.id] else { continue }
                let variant = compact.variant.flatMap { CardVariant(rawValue: $0) } ?? .normal
                let card = variant == dbCard.variant ? dbCard : LorcanaCard(
                    id: dbCard.id,
                    name: dbCard.name,
                    cost: dbCard.cost,
                    type: dbCard.type,
                    rarity: dbCard.rarity,
                    setName: dbCard.setName,
                    cardText: dbCard.cardText,
                    imageUrl: dbCard.imageUrl,
                    price: dbCard.price,
                    variant: variant,
                    cardNumber: dbCard.cardNumber,
                    uniqueId: dbCard.uniqueId,
                    inkwell: dbCard.inkwell,
                    strength: dbCard.strength,
                    willpower: dbCard.willpower,
                    lore: dbCard.lore,
                    franchise: dbCard.franchise,
                    inkColor: dbCard.inkColor
                )
                resolved.append((card, compact.quantity))
            }

            return DecodedSharedDeck(
                name: shareable.name,
                description: shareable.description,
                format: shareable.format,
                inkColors: shareable.inkColors,
                archetype: shareable.archetype,
                cards: resolved,
                totalCards: shareable.cards.reduce(0) { $0 + $1.quantity }
            )
        }

        if code.hasPrefix(Self.sharePrefixV1) {
            let base64 = String(code.dropFirst(Self.sharePrefixV1.count))
            guard let compressedData = Data(base64Encoded: base64),
                  let decompressed = try? (compressedData as NSData).decompressed(using: .lzfse),
                  let shareable = try? JSONDecoder().decode(ShareableDeck.self, from: decompressed as Data) else {
                return nil
            }

            let cards = shareable.cards.map { cardData in
                (
                    card: LorcanaCard(
                        id: cardData.cardId,
                        name: cardData.name,
                        cost: cardData.cost,
                        type: cardData.type,
                        rarity: CardRarity(rawValue: cardData.rarity) ?? .common,
                        setName: cardData.setName,
                        imageUrl: cardData.imageUrl,
                        variant: CardVariant(rawValue: cardData.variant) ?? .normal,
                        inkwell: cardData.inkwell,
                        inkColor: cardData.inkColor
                    ),
                    quantity: cardData.quantity
                )
            }

            return DecodedSharedDeck(
                name: shareable.name,
                description: shareable.description,
                format: shareable.format,
                inkColors: shareable.inkColors,
                archetype: shareable.archetype,
                cards: cards,
                totalCards: shareable.cards.reduce(0) { $0 + $1.quantity }
            )
        }

        return nil
    }

    // MARK: - Base64URL

    /// URL-safe base64 (RFC 4648 §5, unpadded) so share codes survive being embedded in a
    /// `?code=` query without percent-encoding — `+` and `/` are unsafe there.
    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacing("+", with: "-")
            .replacing("/", with: "_")
            .replacing("=", with: "")
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacing("-", with: "+")
            .replacing("_", with: "/")
        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }
        return Data(base64Encoded: base64)
    }

    // MARK: - Update Deck Colors from Cards
    func updateDeckColorsFromCards(_ deck: Deck) {
        // Automatically detect ink colors from added cards
        var detectedColors = Set<InkColor>()

        for card in deck.cards ?? [] {
            if let inkColor = card.cardInkColor {
                detectedColors.insert(inkColor)
            }
        }

        // Only update if we have 1-2 colors
        if detectedColors.count <= 2 && !detectedColors.isEmpty {
            deck.deckInkColors = Array(detectedColors).sorted { $0.rawValue < $1.rawValue }
            deck.lastModified = Date()

            if let context = modelContext {
                try? context.save()
            }
        }
    }
}
