//
//  LorcanaBackground.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

// MARK: - Components/LorcanaBackground.swift
import SwiftUI

struct LorcanaBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),
                    Color(red: 0.1, green: 0.05, blue: 0.15),
                    Color(red: 0.05, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(0..<20, id: \.self) { index in
                let opacity = seededDouble(index: index, min: 0.1, max: 0.3)
                let size = seededDouble(index: index + 100, min: 2, max: 6)
                let xPos = seededDouble(index: index + 200, min: 0, max: 400)
                let yPos = seededDouble(index: index + 300, min: 0, max: 800)
                let duration = seededDouble(index: index + 400, min: 2, max: 5)

                Circle()
                    .fill(Color.lorcanaGold.opacity(opacity))
                    .frame(width: size)
                    .position(x: xPos, y: yPos)
                    .animation(
                        .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true),
                        value: animate
                    )
            }
        }
        .ignoresSafeArea()
        .onAppear { animate = true }
    }

    /// Deterministic pseudo-random value based on index, stable across renders
    private func seededDouble(index: Int, min: Double, max: Double) -> Double {
        // Simple hash-based seeded random
        var hasher = Hasher()
        hasher.combine(index)
        hasher.combine(42) // fixed seed
        let hash = abs(hasher.finalize())
        let normalized = Double(hash % 10000) / 10000.0
        return min + normalized * (max - min)
    }
}
