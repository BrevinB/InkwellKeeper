//
//  HolographicCardImage.swift
//  Inkwell Keeper
//
//  Isolated view for card images with holographic effects.
//  Reads FoilMotion once per frame inside a TimelineView, so motion
//  only redraws this image — never the CardTile around it.
//

import SwiftUI

struct HolographicCardImage: View {
    let card: LorcanaCard
    let reduceMotion: Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var ownsMotionUpdates = false

    private var needsMotion: Bool {
        isVisible && !reduceMotion && scenePhase == .active && [.foil, .enchanted, .epic, .iconic].contains(card.variant)
    }

    var body: some View {
        AsyncImage(url: card.bestImageUrl()) { phase in
            switch phase {
            case .success(let image):
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !needsMotion)) { timeline in
                    let tilt = needsMotion ? FoilMotion.shared.tilt(at: timeline.date).foil : .zero
                    image
                        .resizable().scaledToFit()
                        .interactiveHolographicEffect(
                            pitch: tilt.y,
                            roll: tilt.x,
                            variant: card.variant
                        )
                }
            case .failure:
                cardPlaceholder
            case .empty:
                loadingPlaceholder
            @unknown default:
                unknownPlaceholder
            }
        }
        .onAppear {
            isVisible = true
            updateMotionSubscription()
        }
        .onChange(of: reduceMotion) { updateMotionSubscription() }
        .onChange(of: scenePhase) { updateMotionSubscription() }
        .onChange(of: card.variant) { updateMotionSubscription() }
        .onDisappear {
            isVisible = false
            updateMotionSubscription()
        }
    }

    private func updateMotionSubscription() {
        guard needsMotion != ownsMotionUpdates else { return }
        ownsMotionUpdates = needsMotion
        if needsMotion {
            FoilMotion.shared.begin()
        } else {
            FoilMotion.shared.end()
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
