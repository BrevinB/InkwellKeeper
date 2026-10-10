//
//  DeckPullListView.swift
//  Inkwell Keeper
//
//  Assemble a built deck: every card still to pull, grouped by where it is so you can
//  empty one binder or box at a time. Checking a row moves those copies into the deck
//  box (remembering where they came from); cards you don't have are listed at the end.
//

import SwiftUI

struct DeckPullListView: View {
    let deck: Deck
    let box: StorageContainer

    @Environment(StorageManager.self) private var storageManager
    @Environment(CollectionManager.self) private var collectionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var plan = DeckPullPlan()
    @State private var pulledCount = 0
    @State private var wishlisted = false

    var body: some View {
        List {
            Section {
                DeckPullHeader(box: box, plan: plan, pulledCount: pulledCount)
                    .listRowBackground(Color.clear)
            }

            if plan.isComplete && plan.total > 0 {
                Section {
                    Label("Every card is in the box. Deck built!", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                }
                .listRowBackground(Color.green.opacity(0.12))
            }

            if !plan.pulls.isEmpty {
                Section {
                    Button("Pull All \(plan.toPull) Cards", systemImage: "tray.and.arrow.down.fill", action: pullAll)
                        .foregroundStyle(.lorcanaGold)
                } footer: {
                    Text("Only do this if the cards are already in the box — otherwise check them off as you pull them.")
                }
                .listRowBackground(Color.lorcanaDark.opacity(0.8))
            }

            ForEach(plan.pullsBySource, id: \.sourceName) { group in
                Section {
                    ForEach(group.pulls) { pull in
                        DeckPullRow(pull: pull) { perform(pull) }
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
                    }
                } header: {
                    DeckPullSourceHeader(name: group.sourceName, kind: group.sourceKind, count: group.pulls.reduce(0) { $0 + $1.quantity })
                }
                .listRowBackground(Color.lorcanaDark.opacity(0.8))
            }

            if !plan.missing.isEmpty {
                Section {
                    ForEach(plan.missing) { shortfall in
                        HStack(spacing: 12) {
                            StorageCardThumbnail(card: shortfall.card)
                                .frame(width: 40)
                                .opacity(0.5)
                            Text(shortfall.card.name)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("×\(shortfall.quantity)")
                                .monospacedDigit()
                                .foregroundStyle(.orange)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Button(wishlisted ? "Added to Wishlist" : "Add Missing to Wishlist", systemImage: wishlisted ? "checkmark" : "heart") {
                        for shortfall in plan.missing {
                            collectionManager.addToWishlist(shortfall.card)
                        }
                        withAnimation { wishlisted = true }
                    }
                    .disabled(wishlisted)
                    .foregroundStyle(.lorcanaGold)
                } header: {
                    Text("You Don't Have These")
                } footer: {
                    Text("Cards already in another built deck's box aren't pulled from it.")
                }
                .listRowBackground(Color.lorcanaDark.opacity(0.8))
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: pulledCount)
        .sensoryFeedback(.success, trigger: plan.isComplete && plan.total > 0)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        plan = storageManager.pullPlan(for: deck, into: box)
    }

    private func perform(_ pull: DeckPullPlan.Pull) {
        let moved = storageManager.pull(pull, into: box)
        withAnimation(reduceMotion ? nil : .snappy) {
            pulledCount += moved
            refresh()
        }
        if moved > 0 {
            Analytics.send(.deckCardsPulled(count: moved, all: false))
        }
    }

    private func pullAll() {
        let moved = storageManager.pullAll(plan, into: box)
        withAnimation(reduceMotion ? nil : .snappy) {
            pulledCount += moved
            refresh()
        }
        if moved > 0 {
            Analytics.send(.deckCardsPulled(count: moved, all: true))
        }
    }
}
