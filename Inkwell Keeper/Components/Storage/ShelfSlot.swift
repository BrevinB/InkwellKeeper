//
//  ShelfSlot.swift
//  Inkwell Keeper
//
//  One position on the shelf: the object standing on the plank with a contact
//  shadow at its feet, and its label below the shelf edge.
//

import SwiftUI

struct ShelfSlot<Object: View>: View {
    let title: String
    let subtitle: LocalizedStringKey
    var isHighlighted = false
    @ViewBuilder let object: () -> Object

    var body: some View {
        VStack(spacing: 0) {
            object()
                .frame(maxHeight: ShelfMetrics.objectHeight, alignment: .bottom)
                .background(alignment: .bottom) {
                    // Contact shadow where the object meets the plank.
                    Ellipse()
                        .fill(.black.opacity(0.55))
                        .frame(height: 8)
                        .blur(radius: 3)
                        .offset(y: 3)
                }
                .frame(height: ShelfMetrics.objectZone, alignment: .bottom)
                .offset(y: ShelfMetrics.footing)

            // The plank itself is drawn once behind the whole row.
            Color.clear
                .frame(height: ShelfMetrics.plankHeight)

            VStack(spacing: 1) {
                Text(verbatim: title)
                    .font(.caption)
                    .bold()
                    .foregroundStyle(isHighlighted ? .lorcanaGold : .white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .contentTransition(.numericText())
            }
            .padding(.top, 8)
        }
        .frame(width: ShelfMetrics.itemWidth)
        .contentShape(.rect)
    }
}
