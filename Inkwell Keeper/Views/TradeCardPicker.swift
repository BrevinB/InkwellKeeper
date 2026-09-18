//
//  TradeCardPicker.swift
//  Inkwell Keeper
//
//  Card search used to build a trade side.
//
//  Defaults to the collection, because most of the time a collector is trading
//  away cards they own. The whole catalogue stays one tap away: the other side
//  of a trade is by definition cards they do not own, and people check trades
//  on someone else's behalf.
//

import SwiftUI

struct TradeCardPicker: View {
    let onSelect: (LorcanaCard) -> Void

    @EnvironmentObject private var collectionManager: CollectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var scope: Scope = .owned

    enum Scope: String, CaseIterable, Identifiable {
        case owned = "My Cards"
        case all = "All Cards"

        var id: String { rawValue }
    }

    /// Owned cards, newest first, de-duplicated by printing.
    private var ownedCards: [LorcanaCard] {
        var seen: Set<String> = []
        return collectionManager.collectedCards.filter { seen.insert($0.variantAwareId).inserted }
    }

    private var results: [LorcanaCard] {
        switch scope {
        case .owned:
            // An empty query lists the whole collection, which is the common
            // case: you are picking from cards you already have.
            guard !query.isEmpty else { return ownedCards }
            return ownedCards.filter {
                $0.name.localizedStandardContains(query)
                    || $0.setName.localizedStandardContains(query)
            }
        case .all:
            guard query.count >= 2 else { return [] }
            return Array(SetsDataManager.shared.searchCards(query: query).prefix(40))
        }
    }

    private var emptyMessage: String {
        switch scope {
        case .owned:
            return ownedCards.isEmpty
                ? "You haven't added any cards yet. Switch to All Cards to search the full catalogue."
                : "None of your cards match “\(query)”."
        case .all:
            return query.count < 2
                ? "Type at least two letters to search."
                : "No cards match “\(query)”."
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Search in", selection: $scope) {
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
            .searchable(text: $query, prompt: scope == .owned ? "Search your cards" : "Search all cards")
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
