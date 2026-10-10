//
//  SwayEffect.swift
//  Inkwell Keeper
//
//  A slow, endless side-to-side turn, as if the object were on a display stand.
//

import SwiftUI

struct SwayEffect: ViewModifier {
    let isEnabled: Bool
    var degrees: Double = 10

    func body(content: Content) -> some View {
        content.phaseAnimator([false, true]) { view, swayed in
            view.rotation3DEffect(
                .degrees(isEnabled ? (swayed ? degrees : -degrees) : 0),
                axis: (x: 0.15, y: 1, z: 0),
                perspective: 0.5
            )
        } animation: { _ in
            .easeInOut(duration: 2.6)
        }
    }
}
