//
//  SetFilterEngineTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for the set-browsing filter/sort engine.
//

import Testing
@testable import Inkwell_Keeper

struct SetFilterEngineTests {
    private func card(
        id: String,
        name: String = "Card",
        rarity: CardRarity = .common,
        variant: CardVariant = .normal,
        inkColor: String? = "Amber",
        number: Int? = 1
    ) -> LorcanaCard {
        LorcanaCard(
            id: id,
            name: name,
            cost: 3,
            type: "Character",
            rarity: rarity,
            setName: "Test Set",
            imageUrl: "",
            variant: variant,
            cardNumber: number,
            inkColor: inkColor
        )
    }

    private var sampleCards: [LorcanaCard] {
        [
            card(id: "a", name: "Amber Common", rarity: .common, inkColor: "Amber", number: 1),
            card(id: "b", name: "Ruby Legendary", rarity: .legendary, inkColor: "Ruby", number: 2),
            card(id: "c", name: "Dual Ink", rarity: .rare, inkColor: "Amber-Ruby", number: 3),
            card(id: "d", name: "Enchanted Alt", rarity: .enchanted, variant: .enchanted, inkColor: "Sapphire", number: 205)
        ]
    }

    private func apply(
        ownership: SetOwnershipFilter = .all,
        inkColor: InkColorFilter = .all,
        rarity: CardRarity? = nil,
        variant: VariantFilter = .all,
        price: PriceFilter = .all,
        search: String = "",
        prices: [String: Double] = [:],
        owned: Set<String> = []
    ) -> [String] {
        SetCardFilterEngine.apply(
            to: sampleCards,
            ownership: ownership,
            inkColor: inkColor,
            rarity: rarity,
            variant: variant,
            price: price,
            searchText: search,
            prices: prices,
            isOwned: { owned.contains($0.id) }
        ).map(\.id)
    }

    @Test func ownershipFilters() {
        #expect(apply(ownership: .owned, owned: ["a", "c"]) == ["a", "c"])
        #expect(apply(ownership: .missing, owned: ["a", "c"]) == ["b", "d"])
        #expect(apply(ownership: .all, owned: ["a"]).count == 4)
    }

    /// Dual-ink cards must match either of their colors
    @Test func inkColorMatchesDualInk() {
        #expect(apply(inkColor: .ruby) == ["b", "c"])
        #expect(apply(inkColor: .amber) == ["a", "c"])
    }

    @Test func rarityFilter() {
        #expect(apply(rarity: .legendary) == ["b"])
        #expect(apply(rarity: nil).count == 4)
    }

    @Test func variantFilter() {
        #expect(apply(variant: .enchanted) == ["d"])
        #expect(apply(variant: .normal) == ["a", "b", "c"])
    }

    @Test func priceBuckets() {
        let prices = ["a": 0.25, "b": 42.0, "c": 3.0]
        #expect(apply(price: .underOne, prices: prices) == ["a"])
        #expect(apply(price: .oneToFive, prices: prices) == ["c"])
        #expect(apply(price: .twentyPlus, prices: prices) == ["b"])
        // Unpriced card "d" only appears with no price filter
        #expect(apply(price: .all, prices: prices).count == 4)
    }

    @Test func filtersCombine() {
        let prices = ["c": 3.0]
        let result = apply(inkColor: .ruby, rarity: .rare, price: .oneToFive, prices: prices)
        #expect(result == ["c"])
    }

    @Test func sortByPriceLeavesUnpricedLast() {
        let prices = ["a": 0.25, "b": 42.0, "c": 3.0]
        let high = SetCardFilterEngine.sort(sampleCards, by: .priceHighToLow, prices: prices).map(\.id)
        #expect(high == ["b", "c", "a", "d"])
        let low = SetCardFilterEngine.sort(sampleCards, by: .priceLowToHigh, prices: prices).map(\.id)
        #expect(low == ["a", "c", "b", "d"])
    }

    @Test func sortByRarityPutsRarestFirst() {
        let sorted = SetCardFilterEngine.sort(sampleCards, by: .rarity, prices: [:]).map(\.id)
        #expect(sorted == ["d", "b", "c", "a"])
    }

    /// Rarity hierarchy, rarest first: Iconic > Enchanted > Epic > Legendary >
    /// Super Rare > Rare > Uncommon > Common. Epic sits BELOW Enchanted.
    @Test func rarityHierarchyOrder() {
        let ascending: [CardRarity] = [.common, .uncommon, .rare, .superRare, .legendary, .epic, .enchanted, .iconic]
        let orders = ascending.map(\.sortOrder)
        #expect(orders == orders.sorted(), "sortOrder must ascend through the hierarchy")
        #expect(CardRarity.enchanted.sortOrder > CardRarity.epic.sortOrder)
        #expect(CardRarity.iconic.sortOrder > CardRarity.enchanted.sortOrder)

        let cards = [
            card(id: "epic", rarity: .epic, number: 1),
            card(id: "iconic", rarity: .iconic, number: 2),
            card(id: "enchanted", rarity: .enchanted, number: 3)
        ]
        let sorted = SetCardFilterEngine.sort(cards, by: .rarity, prices: [:]).map(\.id)
        #expect(sorted == ["iconic", "enchanted", "epic"])
    }
}
