//
//  HolographicCardImage.swift
//  Inkwell Keeper
//
//  Isolated view for card images with holographic effects.
//  Observes MotionManager internally so motion updates only rebuild
//  this small view — not the entire CardTile parent.
//

import SwiftUI

struct HolographicCardImage: View {
    let card: LorcanaCard
    let reduceMotion: Bool

    @ObservedObject private var motionManager = MotionManager.shared

    var body: some View {
        AsyncImage(url: card.bestImageUrl()) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .interactiveHolographicEffect(
                        pitch: reduceMotion ? 0 : motionManager.pitch,
                        roll: reduceMotion ? 0 : motionManager.roll,
                        variant: card.variant
                    )
            case .failure:
                cardPlaceholder
            case .empty:
                loadingPlaceholder
            @unknown default:
                unknownPlaceholder
            }
        }
        .onAppear {
            if !reduceMotion {
                motionManager.start()
            }
        }
        .onDisappear {
            motionManager.stop()
        }
    }

    private var cardPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [card.rarity.color.opacity(0.3), card.rarity.color.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo.artframe")
                        .font(.largeTitle)
                        .foregroundStyle(card.rarity.color)
                    Text(card.name)
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding()
            }
    }

    private var loadingPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.gray)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
    }

    private var unknownPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "questionmark")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
    }
}
