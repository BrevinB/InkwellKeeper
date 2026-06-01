//
//  CelebrationBurst.swift
//  Inkwell Keeper
//
//  A one-shot celebratory burst — expanding rings and radiating sparkles.
//  Used when a rare card is revealed or a pack is torn open.
//

import SwiftUI

struct CelebrationBurst: View {
    var color: Color = .lorcanaGold
    var sparkleCount: Int = 14

    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(color.opacity(0.7), lineWidth: 4)
                    .frame(width: 130, height: 130)
                    .scaleEffect(animate ? 2.6 : 0.3)
                    .opacity(animate ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: 0.95).delay(Double(ring) * 0.12),
                        value: animate
                    )
            }

            ForEach(0..<sparkleCount, id: \.self) { index in
                let angle = Double(index) / Double(sparkleCount) * 2 * .pi
                Image(systemName: "sparkle")
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .offset(
                        x: animate ? cos(angle) * 150 : 0,
                        y: animate ? sin(angle) * 150 : 0
                    )
                    .scaleEffect(animate ? 0.2 : 1.1)
                    .opacity(animate ? 0 : 1)
                    .animation(.easeOut(duration: 0.85).delay(0.05), value: animate)
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

#Preview {
    CelebrationBurst(color: .orange, sparkleCount: 16)
        .frame(width: 300, height: 300)
        .background(.black)
}
