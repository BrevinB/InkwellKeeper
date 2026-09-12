//
//  InteractiveHolographicEffect.swift
//  Inkwell Keeper
//
//  Motion-reactive holographic effects for foil cards
//

import SwiftUI

struct InteractiveHolographicEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pitch: Double
    let roll: Double
    let variant: CardVariant

    // Keep highlights bounded, including during spring overshoot.
    private var lightPitch: Double { reduceMotion ? 0 : min(max(pitch, -1), 1) }
    private var lightRoll: Double { reduceMotion ? 0 : min(max(roll, -1), 1) }

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
                .overlay {
                    // Measure the fitted image once; overlays never drive card layout.
                    GeometryReader { geometry in
                        ZStack {
                            primaryShimmerLayer(size: geometry.size)
                                .blendMode(.screen)
                            rainbowHolographicLayer(size: geometry.size)
                                .blendMode(.softLight)
                            sparkleLayer
                                .blendMode(.screen)
                            edgeHighlightLayer(size: geometry.size)
                                .blendMode(.softLight)
                        }
                    }
                    .clipped()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
        } else {
            content
        }
    }

    // MARK: - Primary Shimmer Layer - Radial spotlight effect

    private func primaryShimmerLayer(size: CGSize) -> some View {
        Group {
            // Position the spotlight based on tilt - wider movement range
            let spotX = 0.5 - lightRoll * 0.6
            let spotY = 0.5 - lightPitch * 0.6

            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .white.opacity(0.28 * effectIntensity), location: 0.0),
                    .init(color: .white.opacity(0.16 * effectIntensity), location: 0.2),
                    .init(color: .white.opacity(0.08 * effectIntensity), location: 0.4),
                    .init(color: .white.opacity(0.03 * effectIntensity), location: 0.6),
                    .init(color: .clear, location: 0.85)
                ]),
                center: UnitPoint(x: spotX, y: spotY),
                startRadius: 0,
                endRadius: size.width * 1.2
            )
        }
    }

    // MARK: - Rainbow Holographic Layer - Color refraction around spotlight

    private func rainbowHolographicLayer(size: CGSize) -> some View {
        Group {
            // Rainbow follows the spotlight position
            let spotX = 0.5 - lightRoll * 0.55
            let spotY = 0.5 - lightPitch * 0.55

            // Calculate hue based on tilt angle for color shifting
            // Continuous around neutral tilt; atan2 caused abrupt hue changes there.
            let hueShift = 0.5 + lightRoll * 0.18 + lightPitch * 0.12

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
                endRadius: size.width * 1.3
            )
        }
    }

    // MARK: - Sparkle Layer - Scattered glints that light up near spotlight

    private var sparkleLayer: some View {
        Group {
            // Spotlight position for sparkle activation
            let spotX = 0.5 - lightRoll * 0.6
            let spotY = 0.5 - lightPitch * 0.6

            Canvas { context, size in
                // More sparkles for special variants
                let sparkleCount = variant == .enchanted || variant == .epic || variant == .iconic ? 35 : 20
                guard size.width > 0, size.height > 0 else { return }

                for i in 0..<sparkleCount {
                    // Pseudo-random positions scattered across the card
                    let hash1 = (i * 7919 + 2713) % 10000
                    let hash2 = (i * 4729 + 6311) % 10000
                    let x = CGFloat(hash1) / 10000.0 * size.width
                    let y = CGFloat(hash2) / 10000.0 * size.height

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
                        let radius = min(max(size.width / 250, 0.6), 1.6) * CGFloat(0.7 + brightness * 1.3)
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: x - radius / 2,
                                y: y - radius / 2,
                                width: radius,
                                height: radius
                            )),
                            with: .color(.white.opacity(min(brightness * 0.65, 1)))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Edge Highlight Layer - Subtle rim lighting

    private func edgeHighlightLayer(size: CGSize) -> some View {
        Group {
            // Secondary highlight on opposite side for depth
            let secondaryX = 0.5 + lightRoll * 0.5
            let secondaryY = 0.5 + lightPitch * 0.5

            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .white.opacity(0.08 * effectIntensity), location: 0.0),
                    .init(color: .white.opacity(0.15 * effectIntensity), location: 0.25),
                    .init(color: .white.opacity(0.05 * effectIntensity), location: 0.5),
                    .init(color: .clear, location: 0.75)
                ]),
                center: UnitPoint(x: secondaryX, y: secondaryY),
                startRadius: 0,
                endRadius: size.width * 0.8
            )
        }
    }
}

extension View {
    func interactiveHolographicEffect(pitch: Double, roll: Double, variant: CardVariant) -> some View {
        self.modifier(InteractiveHolographicEffect(pitch: pitch, roll: roll, variant: variant))
    }
}
