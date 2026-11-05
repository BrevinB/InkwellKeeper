//
//  PriceAlertDirectionTile.swift
//  Inkwell Keeper
//
//  One choice in the alert editor's drop-or-rise picker.
//

import SwiftUI

struct PriceAlertDirectionTile: View {
    let direction: PriceAlertDirection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: direction.systemImage)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .black : direction.tint)
                    .frame(width: 34, height: 34)
                    .background(isSelected ? direction.tint : direction.tint.opacity(0.15), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(direction.tileTitle)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.white)
                    Text(direction.tileSubtitle)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? direction.tint.opacity(0.12) : Color.lorcanaDark.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? direction.tint : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
