//
//  HolofoilFinish.swift
//  Inkwell Keeper
//
//  The Holofoil cover finish, modeled on a real holo laminate rather than a wash
//  of rainbow: soft diagonal sweeps of spectrum that melt into the leather, a fine
//  diffraction grain, and a bright glint. Deliberately static, so a shelf full of
//  holofoil binders costs nothing per frame.
//

import SwiftUI

struct HolofoilFinish: View {
    var body: some View {
        ZStack {
            SpectrumSweep()
                .opacity(0.6)
                .blendMode(.overlay)
            DiffractionGrain()
                .blendMode(.overlay)
            Glint()
                .blendMode(.screen)
        }
    }
}

/// Two broad diagonal sweeps of spectrum. Each color eases in and out of clear, so
/// the bands blend into the leather instead of sitting on it like stripes of paint.
private struct SpectrumSweep: View {
    private static let spectrum: [Color] = [
        Color(red: 1.0, green: 0.45, blue: 0.75),
        Color(red: 1.0, green: 0.85, blue: 0.35),
        Color(red: 0.45, green: 1.0, blue: 0.70),
        Color(red: 0.35, green: 0.85, blue: 1.0),
        Color(red: 0.65, green: 0.45, blue: 1.0)
    ]
    private static let cycles = 2

    var body: some View {
        LinearGradient(
            stops: Self.stops,
            startPoint: UnitPoint(x: -0.15, y: -0.15),
            endPoint: UnitPoint(x: 1.15, y: 1.15)
        )
    }

    private static var stops: [Gradient.Stop] {
        var stops: [Gradient.Stop] = []
        let width = 1 / Double(cycles)
        for cycle in 0..<cycles {
            let start = Double(cycle) * width
            stops.append(.init(color: spectrum[0].opacity(0), location: start))
            for (index, color) in spectrum.enumerated() {
                let local = 0.12 + 0.76 * Double(index) / Double(spectrum.count - 1)
                // Strongest in the middle of the sweep, fading toward its edges.
                let strength = sin(.pi * local)
                stops.append(.init(color: color.opacity(strength), location: start + local * width))
            }
            stops.append(.init(color: spectrum[spectrum.count - 1].opacity(0), location: start + width))
        }
        return stops
    }
}

/// Hairline diagonal lines, the embossed grain of a holographic film.
private struct DiffractionGrain: View {
    var body: some View {
        Canvas { context, size in
            let spacing = 2.5
            var path = Path()
            var offset = -size.height
            while offset < size.width {
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                offset += spacing
            }
            context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.6)
        }
    }
}

/// A soft white streak across the upper part of the cover, where the light catches it.
private struct Glint: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.18),
                .init(color: .white.opacity(0.38), location: 0.32),
                .init(color: .clear, location: 0.48)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
