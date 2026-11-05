//
//  InteractiveHolographicEffect.swift
//  Inkwell Keeper
//
//  Motion-reactive holographic effects for foil cards
//

import SwiftUI

/// Holographic foil over a card's art: a rainbow sheen, a soft highlight, and glitter
/// that move with the tilt (`FoilShader.metal`).
///
/// The shader only touches the card's own pixels, so it follows the art's rounded
/// corners and never draws a box around the image. Apply it to the image itself, not
/// to an overlay. The view structure is the same with or without foil, so switching
/// variants never reloads the art.
struct InteractiveHolographicEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pitch: Double
    let roll: Double
    let variant: CardVariant

    /// A flattering fixed angle for when motion is reduced.
    static let stillPitch = -0.25
    static let stillRoll = 0.35

    private var effectIntensity: Double {
        switch variant {
        case .enchanted, .epic, .iconic:
            return 1.2  // Extra sparkly for rare variants
        case .foil:
            return 1.0
        case .normal, .borderless, .promo:
            return 0.0
        }
    }

    func body(content: Content) -> some View {
        // Keep the light bounded, including during spring overshoot.
        let tiltX = reduceMotion ? Self.stillRoll : min(max(roll, -1), 1)
        let tiltY = reduceMotion ? Self.stillPitch : min(max(pitch, -1), 1)
        let intensity = effectIntensity
        content
            .visualEffect { effect, proxy in
                effect.colorEffect(
                    ShaderLibrary.foil(
                        .float2(proxy.size),
                        .float2(Float(tiltX), Float(tiltY)),
                        .float(Float(intensity))
                    ),
                    isEnabled: intensity > 0
                )
            }
    }
}

extension View {
    func interactiveHolographicEffect(pitch: Double, roll: Double, variant: CardVariant) -> some View {
        self.modifier(InteractiveHolographicEffect(pitch: pitch, roll: roll, variant: variant))
    }
}
