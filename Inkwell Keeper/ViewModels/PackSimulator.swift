//
//  PackSimulator.swift
//  Inkwell Keeper
//
//  Drives the "rip open a pack" experience: generates randomized booster
//  packs from locally bundled set data and tracks the reveal flow.
//

import Foundation
import Observation

@MainActor
@Observable
final class PackSimulator {
    /// Stages of the pack-opening experience.
    enum Phase: Equatable {
        case choosingSet
        case sealed
        case revealing
        case summary
    }

    private(set) var phase: Phase = .choosingSet
    private(set) var selectedSet: LorcanaSet?
    private(set) var currentPack: PackResult?

    /// How many slots the user has fully revealed during the `.revealing` phase.
    private(set) var revealedCount = 0

    private let setsManager: SetsDataManager

    init(setsManager: SetsDataManager = .shared) {
        self.setsManager = setsManager
    }

    // MARK: - Pack contents

    /// Total cards in a simulated booster pack.
    static let packSize = 12

    /// Sets that can be opened as packs — only full expansions with a complete
    /// rarity spread (promos, challenge decks, etc. are excluded automatically).
    var boosterSets: [LorcanaSet] {
        setsManager.getAllSets().filter { set in
            let cards = setsManager.getCardsForSet(set.name)
            let common = cards.count { $0.rarity == .common }
            let uncommon = cards.count { $0.rarity == .uncommon }
            let rarePlus = cards.count { $0.rarity.sortOrder >= CardRarity.rare.sortOrder }
            return common >= 6 && uncommon >= 3 && rarePlus >= 2
        }
    }

    // MARK: - Flow

    func selectSet(_ set: LorcanaSet) {
        selectedSet = set
        currentPack = nil
        revealedCount = 0
        phase = .sealed
    }

    func openPack() {
        guard let set = selectedSet else { return }
        currentPack = Self.generatePack(for: set, using: setsManager)
        revealedCount = 0
        phase = .revealing
    }

    func revealNext() {
        guard let pack = currentPack else { return }
        if revealedCount < pack.slots.count {
            revealedCount += 1
        }
        if revealedCount >= pack.slots.count {
            phase = .summary
        }
    }

    func revealAll() {
        guard let pack = currentPack else { return }
        revealedCount = pack.slots.count
        phase = .summary
    }

    /// Open another pack from the same set.
    func openAnother() {
        currentPack = nil
        revealedCount = 0
        phase = .sealed
    }

    /// Return to the set picker.
    func reset() {
        selectedSet = nil
        currentPack = nil
        revealedCount = 0
        phase = .choosingSet
    }

    // MARK: - Generation

    /// Builds a 12-card pack mirroring real Lorcana booster odds:
    /// 6 common, 3 uncommon, 2 rare-or-better, and 1 guaranteed foil that
    /// can climb all the way to an Enchanted card.
    static func generatePack(for set: LorcanaSet, using manager: SetsDataManager) -> PackResult {
        let pool = manager.getCardsForSet(set.name)
        var usedIDs: Set<String> = []
        var slots: [PackSlot] = []

        func add(rarity: CardRarity, foil: Bool) {
            guard let card = pickCard(rarity: rarity, from: pool, excluding: &usedIDs) else { return }
            // Normal cards in the foil slot get a Foil finish; Enchanted/special
            // cards keep their own artwork (which is already holographic).
            let finalCard = (foil && card.variant == .normal) ? card.withVariant(.foil) : card
            slots.append(PackSlot(card: finalCard, isFoil: foil))
        }

        for _ in 0..<6 { add(rarity: .common, foil: false) }
        for _ in 0..<3 { add(rarity: .uncommon, foil: false) }
        for _ in 0..<2 { add(rarity: rollRarePlus(), foil: false) }
        add(rarity: rollFoilRarity(), foil: true)

        return PackResult(setName: set.name, slots: slots)
    }

    /// Picks a random unused card of the requested rarity, stepping down a tier
    /// if that rarity is exhausted (or absent for this set).
    private static func pickCard(rarity: CardRarity,
                                  from pool: [LorcanaCard],
                                  excluding usedIDs: inout Set<String>) -> LorcanaCard? {
        let order: [CardRarity] = [.enchanted, .legendary, .superRare, .rare, .uncommon, .common]
        guard let startIndex = order.firstIndex(of: rarity) else { return nil }

        for candidateRarity in order[startIndex...] {
            let candidates = pool.filter { $0.rarity == candidateRarity && !usedIDs.contains($0.id) }
            if let pick = candidates.randomElement() {
                usedIDs.insert(pick.id)
                return pick
            }
        }
        // Last resort: any unused card so the pack always fills.
        if let pick = pool.filter({ !usedIDs.contains($0.id) }).randomElement() {
            usedIDs.insert(pick.id)
            return pick
        }
        return nil
    }

    /// Weighted roll for the two "rare or better" slots.
    private static func rollRarePlus() -> CardRarity {
        weightedRarity([(.rare, 70), (.superRare, 24), (.legendary, 6)])
    }

    /// Weighted roll for the guaranteed foil slot — mostly low rarity, with a
    /// small Enchanted chase.
    private static func rollFoilRarity() -> CardRarity {
        weightedRarity([
            (.common, 48), (.uncommon, 28), (.rare, 13),
            (.superRare, 6), (.legendary, 3), (.enchanted, 2)
        ])
    }

    private static func weightedRarity(_ weights: [(CardRarity, Int)]) -> CardRarity {
        let total = weights.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return .common }
        var roll = Int.random(in: 0..<total)
        for (rarity, weight) in weights {
            if roll < weight { return rarity }
            roll -= weight
        }
        return weights.last?.0 ?? .common
    }
}
