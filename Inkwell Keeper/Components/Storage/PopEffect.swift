//
//  PopEffect.swift
//  Inkwell Keeper
//
//  A quick springy scale bump whenever `trigger` changes.
//

import SwiftUI

struct PopEffect<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    let isEnabled: Bool
    var peak: Double = 1.08

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(isEnabled ? peak : 1.0, duration: 0.14)
            SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
        }
    }
}
