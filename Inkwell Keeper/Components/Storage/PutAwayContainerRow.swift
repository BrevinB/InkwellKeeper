//
//  PutAwayContainerRow.swift
//  Inkwell Keeper
//
//  A container choice in the Put Away sheet. The chosen one pops and checks off.
//

import SwiftUI

struct PutAwayContainerRow: View {
    let container: StorageContainer
    let isChosen: Bool
    /// Copies that still fit; nil when the container has no limit.
    let freeSpace: Int?
    /// Why this card can't go here (full, wrong set, pocket taken); nil when it can.
    var refusal: String?
    /// Shown instead of the detail when putting this card here upgrades a normal copy.
    var upgradeNote: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            ContainerArtwork(kind: container.kind, color: container.coverColor, style: container.cover, lidLift: isChosen ? 1 : 0)
                .frame(width: 44, height: 44)
                .modifier(PopEffect(trigger: isChosen, isEnabled: !reduceMotion, peak: 1.25))

            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .foregroundStyle(.white)
                if let upgradeNote {
                    Label(upgradeNote, systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.lorcanaGold)
                } else {
                    Text(refusal ?? detail)
                        .font(.caption)
                        .foregroundStyle(refusal == nil ? .gray : .orange)
                }
            }

            Spacer()

            if isChosen {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else if isFull {
                FullBadge()
            }
        }
        .opacity(refusal != nil && !isChosen ? 0.5 : 1)
        .animation(.bouncy, value: isChosen)
    }

    private var isFull: Bool { freeSpace == 0 }

    private var detail: String {
        if let capacity = container.capacity {
            return "\(container.kind.displayName) · \(container.cardCount) of \(capacity)"
        }
        if container.kind.usesSlots {
            return "\(container.kind.displayName) · \(freeSpace ?? 0) pockets free"
        }
        return "\(container.kind.displayName) · \(container.cardCount) cards"
    }
}
