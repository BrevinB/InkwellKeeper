//
//  FoilEffect.swift
//  Inkwell Keeper
//
//  Foil/holographic effect for card images
//

import SwiftUI

/// Adds a shimmering foil/holographic effect overlay to card images
/// Mimics the official Lorcana app's diagonal shimmer pattern
struct FoilEffect: ViewModifier {
    @State private var shimmerOffset: CGFloat = -1.5
    @State private var glowIntensity: Double = 0.4
    let isAnimated: Bool

    init(isAnimated: Bool = true) {
        self.isAnimated = isAnimated
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                // Diagonal shimmer bands (like official Lorcana app)
                ZStack {
                    // Primary shimmer band
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.4),
                            .init(color: .white.opacity(0.15 * glowIntensity), location: 0.45),
                            .init(color: .white.opacity(0.3 * glowIntensity), location: 0.5),
                            .init(color: .white.opacity(0.15 * glowIntensity), location: 0.55),
                            .init(color: .clear, location: 0.6),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(45))
                    .offset(x: shimmerOffset * 600, y: shimmerOffset * 300)
                    .blendMode(.screen)

                    // Secondary rainbow shimmer
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.35),
                            .init(color: Color.cyan.opacity(0.2 * glowIntensity), location: 0.4),
                            .init(color: Color.purple.opacity(0.15 * glowIntensity), location: 0.45),
                            .init(color: Color.blue.opacity(0.2 * glowIntensity), location: 0.5),
                            .init(color: Color.cyan.opacity(0.15 * glowIntensity), location: 0.55),
                            .init(color: .clear, location: 0.6),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(45))
                    .offset(x: shimmerOffset * 600, y: shimmerOffset * 300)
                    .blendMode(.screen)
                }
                .mask(content)
            )
            .overlay(
                // Subtle holographic sparkles
                GeometryReader { geometry in
                    Canvas { context, size in
                        // Add fewer, more subtle sparkle points
                        for _ in 0..<8 {
                            let x = CGFloat.random(in: 0...size.width)
                            let y = CGFloat.random(in: 0...size.height)
                            let radius = CGFloat.random(in: 0.5...1.5)

                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                                with: .color(.white.opacity(0.4 * glowIntensity))
                            )
                        }
                    }
                }
                .blendMode(.screen)
            )
            .onAppear {
                if isAnimated {
                    // Continuous diagonal shimmer sweep (like official app)
                    withAnimation(
                        Animation.linear(duration: 4.0)
                            .repeatForever(autoreverses: false)
                    ) {
                        shimmerOffset = 1.5
                    }

                    // Subtle glow intensity pulse
                    withAnimation(
                        Animation.easeInOut(duration: 2.5)
                            .repeatForever(autoreverses: true)
                    ) {
                        glowIntensity = 0.6
                    }
                }
            }
    }
}

/// Simple static foil effect without animation (for lists/grids)
struct StaticFoilEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                // Static rainbow gradient
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
                .blendMode(.screen)
            )
            .overlay(
                // Subtle shine
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .center
                )
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
