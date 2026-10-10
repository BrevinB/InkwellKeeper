//
//  FocusPulse.swift
//  Inkwell Keeper
//
//  A gold ring that pulses a few times to say "your card is here".
//

import SwiftUI

struct FocusPulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulses = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(Color.lorcanaGold, lineWidth: 3)
            .padding(-3)
            .keyframeAnimator(initialValue: 1.0, trigger: pulses) { ring, scale in
                ring
                    .scaleEffect(scale)
                    .opacity(2 - scale)
            } keyframes: { _ in
                SpringKeyframe(1.12, duration: 0.3)
                SpringKeyframe(1.0, duration: 0.3)
                SpringKeyframe(1.12, duration: 0.3)
                SpringKeyframe(1.0, duration: 0.3)
                SpringKeyframe(1.12, duration: 0.3)
                SpringKeyframe(1.0, duration: 0.3)
            }
            .shadow(color: .lorcanaGold, radius: 8)
            .onAppear {
                if !reduceMotion { pulses += 1 }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
