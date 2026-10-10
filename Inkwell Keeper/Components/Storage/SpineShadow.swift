//
//  SpineShadow.swift
//  Inkwell Keeper
//
//  The crease down the middle of an open binder, with its metal rings.
//

import SwiftUI

struct SpineShadow: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.44),
                    .init(color: .black.opacity(0.45), location: 0.5),
                    .init(color: .clear, location: 0.56)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            BinderRings()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
