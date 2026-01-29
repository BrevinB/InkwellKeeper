//
//  FullscreenCardViewer.swift
//  Inkwell Keeper
//
//  Immersive fullscreen presentation for interactive card viewing
//

import SwiftUI

struct FullscreenCardViewer: View {
    let card: LorcanaCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                }

                Spacer()

                // Interactive card
                InteractiveCardView(card: card)
                    .padding(.horizontal, 40)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.65)

                // Card name
                Text(card.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Variant badge for special cards
                if card.variant != .normal {
                    Text(card.variant.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(variantColor.opacity(0.6))
                        )
                }

                Spacer()

                // Hint text
                Text("Tilt your device to see the holographic effect")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 30)
            }
        }
        .onTapGesture {
            dismiss()
        }
        .statusBarHidden(true)
    }

    private var variantColor: Color {
        switch card.variant {
        case .foil:
            return .purple
        case .enchanted:
            return .blue
        case .epic:
            return .orange
        case .iconic:
            return .yellow
        case .promo:
            return .green
        case .borderless:
            return .gray
        case .normal:
            return .clear
        }
    }
}
