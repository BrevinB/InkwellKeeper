//
//  PocketView.swift
//  Inkwell Keeper
//
//  One plastic pocket on a binder page: a sleeved card, a faded "missing" ghost in
//  set binders, or an empty dashed slot. Cards drop in with a springy cascade, and
//  a picked-up card lifts and tilts in arrange mode.
//

import SwiftUI

struct PocketView: View {
    let item: StoredCard?
    /// The card that belongs here in a set binder, shown faded when the pocket is empty.
    let ghost: LorcanaCard?
    /// Position on the page, used to stagger the drop-in cascade.
    let pocketIndex: Int
    let isPickedUp: Bool
    let isFocused: Bool
    let namespace: Namespace.ID
    /// An unsorted foil could replace the normal copy in this pocket.
    var canUpgrade = false
    /// Whether this card is chosen in select mode; nil when not selecting.
    var isSelected: Bool?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.14), lineWidth: 0.75)

            if let item {
                StorageCardThumbnail(card: item.toLorcanaCard)
                    .padding(2)
                    .matchedGeometryEffect(id: item.id, in: namespace)
                    .transition(reduceMotion ? .opacity : .dropIntoPocket)
            } else if let ghost {
                StorageCardThumbnail(card: ghost)
                    .padding(2)
                    .saturation(0)
                    .opacity(0.22)
                    .overlay(alignment: .bottom) {
                        if let number = ghost.cardNumber {
                            Text("#\(number)")
                                .font(.caption2)
                                .bold()
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.bottom, 4)
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .padding(3)
            }

            // The sleeve's plastic sheen.
            LinearGradient(
                colors: [.white.opacity(0.16), .clear, .white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(.rect(cornerRadius: 5))
            .allowsHitTesting(false)
        }
        .aspectRatio(63 / 88, contentMode: .fit)
        .overlay(alignment: .bottomTrailing) {
            if canUpgrade {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(Color.lorcanaDark)
                    .padding(4)
                    .background(Circle().fill(Color.lorcanaGold))
                    .padding(3)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .overlay {
            if isFocused {
                FocusPulse()
            }
        }
        .selectionMark(isSelected, cornerRadius: 5)
        .scaleEffect(isPickedUp ? 1.1 : 1)
        .rotationEffect(.degrees(isPickedUp && !reduceMotion ? -3 : 0))
        .shadow(color: .lorcanaGold.opacity(isPickedUp ? 0.7 : 0), radius: isPickedUp ? 10 : 0)
        .zIndex(isPickedUp ? 1 : 0)
        .animation(.spring(duration: 0.45, bounce: 0.35).delay(reduceMotion ? 0 : Double(pocketIndex) * 0.04), value: item?.id)
        .animation(.snappy, value: isPickedUp)
    }
}

private extension AnyTransition {
    /// The card falls into the pocket from above and settles.
    static var dropIntoPocket: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 1.35).combined(with: .opacity).combined(with: .offset(y: -28)),
            removal: .opacity.combined(with: .scale(scale: 0.9))
        )
    }
}
