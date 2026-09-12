//
//  FoilEffect.swift
//  Inkwell Keeper
//
//  Foil/holographic effect for card images
//

import SwiftUI

/// A gentle automatic light sweep using the same foil finish as interactive cards.
struct FoilEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let isAnimated: Bool

    init(isAnimated: Bool = true) {
        self.isAnimated = isAnimated
    }

    func body(content: Content) -> some View {
        let animates = isAnimated && !reduceMotion && scenePhase == .active
        content
            .overlay {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animates)) { timeline in
                    let phase = animates ? timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 8) * .pi / 4 : 0
                    Color.clear
                        .interactiveHolographicEffect(
                            pitch: animates ? sin(phase) * 0.45 : 0,
                            roll: animates ? cos(phase) * 0.6 : 0,
                            variant: .foil
                        )
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}

/// Simple static foil effect without animation (for lists/grids)
struct StaticFoilEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                // Static rainbow gradient
                Group {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.purple.opacity(0.2),
                            Color.cyan.opacity(0.2),
                            Color.yellow.opacity(0.2),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .blendMode(.screen)
            )
            .overlay(
                // Subtle shine
                Group {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                }
                .blendMode(.screen)
            )
    }
}

extension View {
    /// Apply animated foil/holographic effect
    func foilEffect(isAnimated: Bool = true) -> some View {
        self.modifier(FoilEffect(isAnimated: isAnimated))
    }

    /// Apply static foil effect (better for performance in lists)
    func staticFoilEffect() -> some View {
        self.modifier(StaticFoilEffect())
    }
}
