//
//  SpoilerSettings.swift
//  Inkwell Keeper
//
//  Spoiler shield for sets that haven't released yet. Upcoming sets are covered until the user
//  opts in (per set, remembered) or turns the shield off entirely in Settings. Cards that turn
//  up incidentally in search can be revealed one at a time for the session. Everything lifts on
//  its own at release day — see `ReleaseSchedule`.
//
//  Cards the user owns (collection, scanner, imports) are never shielded; only catalog browsing
//  surfaces consult this.
//

import Foundation
import Observation

@MainActor
@Observable
final class SpoilerSettings {
    static let shared = SpoilerSettings()

    private static let showAllKey = "spoilers.showAll"
    private static let revealedSetsKey = "spoilers.revealedSetNames"

    /// When on, nothing is shielded.
    var showAllSpoilers: Bool {
        didSet { defaults.set(showAllSpoilers, forKey: Self.showAllKey) }
    }

    /// Upcoming sets the user chose to see, by set name. Persisted.
    private(set) var revealedSetNames: Set<String> {
        didSet { defaults.set(Array(revealedSetNames), forKey: Self.revealedSetsKey) }
    }

    /// Individual cards revealed from a search row. Session-only on purpose: tapping one card
    /// shouldn't opt the user in to that card forever.
    private(set) var revealedCardIds: Set<String> = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let releaseDateForSet: (String) -> String?
    @ObservationIgnored private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        releaseDateForSet: @escaping (String) -> String? = { SetsDataManager.shared.getSet(byName: $0)?.releaseDate },
        now: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.releaseDateForSet = releaseDateForSet
        self.now = now
        showAllSpoilers = defaults.bool(forKey: Self.showAllKey)
        revealedSetNames = Set(defaults.stringArray(forKey: Self.revealedSetsKey) ?? [])
    }

    /// Whether the set's cards should be covered right now.
    func isHidden(setName: String) -> Bool {
        guard !showAllSpoilers, !revealedSetNames.contains(setName) else { return false }
        return ReleaseSchedule.isUpcoming(releaseDate: releaseDateForSet(setName), asOf: now())
    }

    /// Whether this card should be covered right now.
    func isHidden(_ card: LorcanaCard) -> Bool {
        !revealedCardIds.contains(card.id) && isHidden(setName: card.setName)
    }

    /// Drops cards from covered sets — for browse surfaces (deck builder grid, suggestion
    /// pickers) where a placeholder row would just be noise.
    func visibleCards(_ cards: [LorcanaCard]) -> [LorcanaCard] {
        cards.filter { !isHidden(setName: $0.setName) }
    }

    func reveal(setName: String) {
        revealedSetNames.insert(setName)
    }

    func reveal(_ card: LorcanaCard) {
        revealedCardIds.insert(card.id)
    }
}
