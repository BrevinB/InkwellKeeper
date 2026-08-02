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
}
