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
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animates)) { timeline in
            let phase = animates ? timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 8) * .pi / 4 : 0
            content
                .interactiveHolographicEffect(
                    pitch: animates ? sin(phase) * 0.45 : 0,
                    roll: animates ? cos(phase) * 0.6 : 0,
                    variant: .foil
                )
        }
    }
}

/// A still foil sheen at a fixed angle, for cards shown many at a time.
struct StaticFoilEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .interactiveHolographicEffect(
                pitch: InteractiveHolographicEffect.stillPitch,
                roll: InteractiveHolographicEffect.stillRoll,
                variant: .foil
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
