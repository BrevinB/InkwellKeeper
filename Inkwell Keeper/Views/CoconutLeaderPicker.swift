//
//  CoconutLeaderPicker.swift
//  Inkwell Keeper
//
//  Leader selection for Format [Coconut] decks: the 18 beta leaders grouped by ink,
//  with the chosen leader's ability shown so players can build around it.
//

import SwiftUI

struct CoconutLeaderPicker: View {
    @Binding var selection: String?

    /// Fullscreen view of the selected leader's official card image.
    @State private var viewingCard: LorcanaCard?

    private var selectedLeader: CoconutLeader? {
        selection.flatMap { CoconutLeaders.leader(named: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(InkColor.allCases, id: \.self) { ink in
                    Section(ink.rawValue) {
                        ForEach(CoconutLeaders.leaders(for: ink)) { leader in
                            Button {
                                selection = leader.name
                            } label: {
                                if selection == leader.name {
                                    Label(leader.name, systemImage: "checkmark")
                                } else {
                                    Text(leader.name)
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let leader = selectedLeader {
                        Circle()
                            .fill(leader.ink.color)
                            .frame(width: 14, height: 14)
                        Text(leader.name)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .foregroundStyle(.lorcanaGold)
                        Text("Choose a Leader")
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.lorcanaDark.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            if let leader = selectedLeader {
                HStack(alignment: .top, spacing: 10) {
                    // Official leader card image, once Lorcast has ingested it —
                    // they're appearing gradually during the beta.
                    if let imageURL = CoconutLeaderImageService.shared.imageURL(for: leader) {
                        Button {
                            viewingCard = fullscreenCard(for: leader, imageURL: imageURL)
                        } label: {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 74, height: 103)
                            .clipShape(.rect(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.lorcanaGold.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .accessibilityLabel("View \(leader.name) card full size")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(leader.abilityText)
                            .font(.caption)
                            .foregroundStyle(.gray)

                        Text("Up to 4 copies of: \(leader.fourOfCardNames.joined(separator: ", ")). Everything else is 1 copy.")
                            .font(.caption2)
                            .foregroundStyle(.lorcanaGold.opacity(0.8))
                    }
                }
            }
        }
        .fullScreenCover(item: $viewingCard) { card in
            FullscreenCardViewer(card: card)
        }
    }

    /// Minimal card wrapper so the leader's official image opens in the shared viewer.
    private func fullscreenCard(for leader: CoconutLeader, imageURL: URL) -> LorcanaCard {
        LorcanaCard(
            id: "coconut-leader-\(leader.name)",
            name: leader.name,
            cost: 0,
            type: "Coconut Leader",
            rarity: .promo,
            setName: "Format Coconut",
            imageUrl: imageURL.absoluteString
        )
    }
}

// MARK: - Leader Detail Sheet

/// Mid-game reference for a player's leader: the official card (when available) and the
/// ability text. Presented from the lore counter's player cards.
struct CoconutLeaderDetailSheet: View {
    let leader: CoconutLeader
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        if let imageURL = CoconutLeaderImageService.shared.imageURL(for: leader) {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .aspectRatio(1468 / 2048, contentMode: .fit)
                            }
                            .frame(maxWidth: 280)
                            .clipShape(.rect(cornerRadius: 12))
                        } else {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(leader.ink.color)
                                    .frame(width: 16, height: 16)
                                Image(systemName: "crown.fill")
                                    .font(.title)
                                    .foregroundStyle(.lorcanaGold)
                            }
                            .padding(.top, 20)
                        }

                        Text(leader.name)
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(leader.abilityText)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("Deck may run up to 4 copies of: \(leader.fourOfCardNames.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Coconut Leader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.lorcanaGold)
                }
            }
        }
    }
}
