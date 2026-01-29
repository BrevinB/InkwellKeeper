//
//  InteractiveHolographicEffect.swift
//  Inkwell Keeper
//
//  Motion-reactive holographic effects for foil cards
//

import SwiftUI

struct InteractiveHolographicEffect: ViewModifier {
    let pitch: Double
    let roll: Double
    let variant: CardVariant

    private var shouldShowEffect: Bool {
        switch variant {
        case .foil, .enchanted, .epic, .iconic:
            return true
        case .normal, .borderless, .promo:
            return false
        }
    }

    private var effectIntensity: Double {
        switch variant {
        case .enchanted, .epic, .iconic:
            return 1.2  // Extra sparkly for rare variants
        case .foil:
            return 1.0
        default:
            return 0.0
        }
    }

    func body(content: Content) -> some View {
        if shouldShowEffect {
            content
                .overlay(
                    ZStack {
                        primaryShimmerLayer
                        rainbowHolographicLayer
                        sparkleLayer
                    }
                    .blendMode(.overlay)  // Blend with underlying image for natural look
                    .allowsHitTesting(false)
                )
                .overlay(
                    edgeHighlightLayer
                        .blendMode(.softLight)
                        .allowsHitTesting(false)
                )
                .drawingGroup()  // GPU layer flattening for performance
        } else {
            content
        }
    }

    // MARK: - Primary Shimmer Layer - Radial spotlight effect

    private var primaryShimmerLayer: some View {
        GeometryReader { geometry in
            // Position the spotlight based on tilt - wider movement range
            let spotX = 0.5 - roll * 0.6
            let spotY = 0.5 - pitch * 0.6

            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .white.opacity(0.9 * effectIntensity), location: 0.0),
                    .init(color: .white.opacity(0.6 * effectIntensity), location: 0.2),
                    .init(color: .white.opacity(0.3 * effectIntensity), location: 0.4),
                    .init(color: .white.opacity(0.1 * effectIntensity), location: 0.6),
                    .init(color: .clear, location: 0.85)
                ]),
                center: UnitPoint(x: spotX, y: spotY),
                startRadius: 0,
                endRadius: geometry.size.width * 1.2
            )
        }
    }

    // MARK: - Rainbow Holographic Layer - Color refraction around spotlight

    private var rainbowHolographicLayer: some View {
        GeometryReader { geometry in
            // Rainbow follows the spotlight position
            let spotX = 0.5 - roll * 0.55
            let spotY = 0.5 - pitch * 0.55

            // Calculate hue based on tilt angle for color shifting
            let tiltAngle = atan2(pitch, roll)
            let hueShift = (tiltAngle + .pi) / (2 * .pi)  // Normalize to 0-1

            // Create a ring of rainbow color around the spotlight
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color(hue: hueShift, saturation: 0.7, brightness: 1.0).opacity(0.35 * effectIntensity), location: 0.15),
                    .init(color: Color(hue: (hueShift + 0.2).truncatingRemainder(dividingBy: 1.0), saturation: 0.7, brightness: 1.0).opacity(0.4 * effectIntensity), location: 0.3),
                    .init(color: Color(hue: (hueShift + 0.4).truncatingRemainder(dividingBy: 1.0), saturation: 0.6, brightness: 1.0).opacity(0.35 * effectIntensity), location: 0.5),
                    .init(color: Color(hue: (hueShift + 0.6).truncatingRemainder(dividingBy: 1.0), saturation: 0.5, brightness: 1.0).opacity(0.2 * effectIntensity), location: 0.7),
                    .init(color: .clear, location: 0.95)
                ]),
                center: UnitPoint(x: spotX, y: spotY),
                startRadius: 0,
                endRadius: geometry.size.width * 1.3
            )
        }
    }

    // MARK: - Sparkle Layer - Scattered glints that light up near spotlight

    private var sparkleLayer: some View {
        GeometryReader { geometry in
            // Spotlight position for sparkle activation
            let spotX = 0.5 - roll * 0.6
            let spotY = 0.5 - pitch * 0.6

            Canvas { context, size in
                // More sparkles for special variants
                let sparkleCount = variant == .enchanted || variant == .epic || variant == .iconic ? 35 : 20
                let seed = Int(size.width * size.height) % 1000

                for i in 0..<sparkleCount {
                    // Pseudo-random positions scattered across the card
                    let hash1 = (i * 7919 + seed) % 10000
                    let hash2 = (i * 104729 + seed) % 10000
                    let x = CGFloat(hash1 % 100) / 100.0 * size.width
                    let y = CGFloat(hash2 % 100) / 100.0 * size.height

                    // Sparkle lights up based on distance from spotlight
                    let normalizedX = x / size.width
                    let normalizedY = y / size.height
                    let distanceFromSpot = sqrt(
                        pow(normalizedX - spotX, 2) +
                        pow(normalizedY - spotY, 2)
                    )

                    // Wider falloff - sparkles visible in a larger radius
                    let brightness = max(0, 1.0 - distanceFromSpot * 1.8) * effectIntensity

                    if brightness > 0.05 {
                        let radius = CGFloat(1.5 + brightness * 3.5)
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: x - radius / 2,
                                y: y - radius / 2,
                                width: radius,
                                height: radius
                            )),
                            with: .color(.white.opacity(brightness))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Edge Highlight Layer - Subtle rim lighting

    private var edgeHighlightLayer: some View {
        GeometryReader { geometry in
            // Secondary highlight on opposite side for depth
            let secondaryX = 0.5 + roll * 0.5
            let secondaryY = 0.5 + pitch * 0.5

            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .white.opacity(0.3 * effectIntensity), location: 0.0),
                    .init(color: .white.opacity(0.15 * effectIntensity), location: 0.25),
                    .init(color: .white.opacity(0.05 * effectIntensity), location: 0.5),
                    .init(color: .clear, location: 0.75)
                ]),
                center: UnitPoint(x: secondaryX, y: secondaryY),
                startRadius: 0,
                endRadius: geometry.size.width * 0.8
            )
        }
    }
}

extension View {
    func interactiveHolographicEffect(pitch: Double, roll: Double, variant: CardVariant) -> some View {
        self.modifier(InteractiveHolographicEffect(pitch: pitch, roll: roll, variant: variant))
    }
}
