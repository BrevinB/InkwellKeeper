//
//  PackSummaryView.swift
//  Inkwell Keeper
//
//  Final step of the pack-opening flow: shows everything that was pulled.
//

import SwiftUI

struct PackSummaryView: View {
    let simulator: PackSimulator

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        if let pack = simulator.currentPack {
            ScrollView {
                VStack(spacing: 22) {
                    if let best = pack.bestSlot {
                        bestPull(best)
                    }

                    rarityTally(pack)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(pack.slots) { slot in
                            PackCardImageView(slot: slot)
                                .overlay(alignment: .topTrailing) {
                                    if slot.isFoil {
                                        Image(systemName: "sparkles")
                                            .font(.caption2)
                                            .foregroundStyle(Color.lorcanaGold)
                                            .padding(4)
                                            .background(.black.opacity(0.5), in: .circle)
                                            .padding(4)
                                    }
                                }
                        }
                    }

                    PackDisclaimerCard()

                    actionButtons
                }
                .padding()
            }
            .scrollIndicators(.hidden)
        } else {
            ContentUnavailableView("No pack", systemImage: "shippingbox")
        }
    }

    // MARK: - Best pull

    private func bestPull(_ slot: PackSlot) -> some View {
        VStack(spacing: 10) {
            Text("✦ BEST PULL ✦")
                .font(.caption.bold())
                .tracking(2)
                .foregroundStyle(Color.lorcanaGold)

            InteractiveCardView(card: slot.card)
                .aspectRatio(0.717, contentMode: .fit)
                .frame(maxWidth: 200)
                .shadow(color: slot.card.rarity.color.opacity(0.7), radius: 20)

            Text(slot.card.name)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(slot.card.rarity.displayName + (slot.isFoil ? " · Foil" : ""))
                .font(.subheadline)
                .foregroundStyle(slot.card.rarity.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Rarity tally

    private func rarityTally(_ pack: PackResult) -> some View {
        FlowingChips(items: pack.rarityTally)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button("Open another pack", systemImage: "gift.fill") {
                simulator.openAnother()
            }
            .buttonStyle(LorcanaButtonStyle(style: .primary))

            Button("Choose a different set") {
                simulator.reset()
            }
            .buttonStyle(LorcanaButtonStyle(style: .secondary))
        }
    }
}

/// Wrapping row of rarity-count chips.
private struct FlowingChips: View {
    let items: [(rarity: CardRarity, count: Int)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.rarity) { item in
                Text("\(item.rarity.displayName) ×\(item.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(item.rarity.color.opacity(0.22), in: .capsule)
                    .foregroundStyle(item.rarity.color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
