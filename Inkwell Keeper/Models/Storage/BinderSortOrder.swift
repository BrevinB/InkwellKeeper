//
//  BinderSortOrder.swift
//  Inkwell Keeper
//
//  How auto-fill arranges cards into binder pockets.
//

import Foundation

enum BinderSortOrder: String, CaseIterable, Identifiable, Sendable {
    case setNumber
    case ink
    case rarity
    case cost
    case name

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .setNumber: "Set & Number"
        case .ink: "Ink Color"
        case .rarity: "Rarity"
        case .cost: "Ink Cost"
        case .name: "Name"
        }
    }

    var systemImage: String {
        switch self {
        case .setNumber: "number"
        case .ink: "drop.fill"
        case .rarity: "sparkles"
        case .cost: "circle.hexagongrid.fill"
        case .name: "textformat"
        }
    }

    /// Release order for each set name, built from the loaded catalog.
    @MainActor
    static func catalogSetOrder() -> [String: Int] {
        var order: [String: Int] = [:]
        for set in SetsDataManager.shared.sets {
            order[set.name] = Int(set.setNumber ?? "") ?? Int.max
        }
        return order
    }

    /// Sorts cards for placement. Every order falls back to set → number → variant so the
    /// result is stable and matches how collectors file cards physically.
    func sorted(_ cards: [LorcanaCard], setOrder: [String: Int]) -> [LorcanaCard] {
        func setRank(_ card: LorcanaCard) -> Int { setOrder[card.setName] ?? Int.max }
        func variantRank(_ card: LorcanaCard) -> Int {
            CardVariant.allCases.firstIndex(of: card.variant) ?? 0
        }
        func catalogOrder(_ lhs: LorcanaCard, _ rhs: LorcanaCard) -> Bool {
            if setRank(lhs) != setRank(rhs) { return setRank(lhs) < setRank(rhs) }
            if lhs.setName != rhs.setName { return lhs.setName < rhs.setName }
            let lhsNumber = lhs.cardNumber ?? Int.max
            let rhsNumber = rhs.cardNumber ?? Int.max
            if lhsNumber != rhsNumber { return lhsNumber < rhsNumber }
            if variantRank(lhs) != variantRank(rhs) { return variantRank(lhs) < variantRank(rhs) }
            return lhs.name < rhs.name
        }

        return cards.sorted { lhs, rhs in
            switch self {
            case .setNumber:
                return catalogOrder(lhs, rhs)
            case .ink:
                let lhsInk = lhs.inkColor ?? "~"
                let rhsInk = rhs.inkColor ?? "~"
                if lhsInk != rhsInk { return lhsInk < rhsInk }
                return catalogOrder(lhs, rhs)
            case .rarity:
                if lhs.rarity.sortOrder != rhs.rarity.sortOrder { return lhs.rarity.sortOrder > rhs.rarity.sortOrder }
                return catalogOrder(lhs, rhs)
            case .cost:
                if lhs.cost != rhs.cost { return lhs.cost < rhs.cost }
                return catalogOrder(lhs, rhs)
            case .name:
                if lhs.name != rhs.name { return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending }
                return catalogOrder(lhs, rhs)
            }
        }
    }
}
