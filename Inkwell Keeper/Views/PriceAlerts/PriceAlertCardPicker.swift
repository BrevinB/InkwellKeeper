//
//  PriceAlertCardPicker.swift
//  Inkwell Keeper
//
//  Picks the card for a new price alert from the Price Alerts screen. Opens
//  on the wishlist, since those are the cards people wait to buy cheaper.
//

import SwiftUI

struct PriceAlertCardPicker: View {
    let onSelect: (LorcanaCard) -> Void

    @Environment(CollectionManager.self) private var collectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var scope: Scope?

    enum Scope: String, CaseIterable, Identifiable {
        case wishlist = "Wishlist"
        case owned = "My Cards"
        case all = "All Cards"

        var id: String { rawValue }
    }

    private var activeScope: Scope {
        scope ?? (collectionManager.wishlistCards.isEmpty ? .owned : .wishlist)
    }

    private func unique(_ cards: [LorcanaCard]) -> [LorcanaCard] {
        var seen: Set<String> = []
        return cards.filter { seen.insert($0.variantAwareId).inserted }
    }

    private var results: [LorcanaCard] {
        let pool: [LorcanaCard]
        switch activeScope {
        case .wishlist: pool = unique(collectionManager.wishlistCards)
        case .owned: pool = unique(collectionManager.collectedCards)
        case .all:
            guard query.count >= 2 else { return [] }
            return Array(SetsDataManager.shared.searchCards(query: query).prefix(40))
        }
        guard !query.isEmpty else { return pool }
        return pool.filter {
            $0.name.localizedStandardContains(query) || $0.setName.localizedStandardContains(query)
        }
    }

    private var emptyMessage: String {
        switch activeScope {
        case .wishlist where collectionManager.wishlistCards.isEmpty:
            String(localized: "Your wishlist is empty. Search All Cards to watch any card.")
        case .owned where collectionManager.collectedCards.isEmpty:
            String(localized: "You haven't added any cards yet. Search All Cards to watch any card.")
        case .all where query.count < 2:
            String(localized: "Type at least two letters to search.")
        default:
            String(localized: "No cards match “\(query)”.")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(
                    "Search in",
                    selection: Binding(get: { activeScope }, set: { scope = $0 })
                ) {
                    ForEach(Scope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                List {
                    if results.isEmpty {
                        Text(emptyMessage)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(results, id: \.variantAwareId) { card in
                            SimpleCardSearchRow(card: card) { onSelect(card) }
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(LorcanaBackground())
            .searchable(text: $query, prompt: activeScope == .all ? "Search all cards" : "Filter cards")
            .navigationTitle("Watch a Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
