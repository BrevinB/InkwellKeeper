//
//  LeafCastShadow.swift
//  Inkwell Keeper
//
//  The shadow a lifting page throws onto the page beneath it: darkest along the spine
//  and strongest while the sheet is standing up, gone once it lies flat again.
//  Animatable, so it tracks the same interpolated angle as the turning `PageLeaf`.
//

import SwiftUI

struct LeafCastShadow: View, Animatable {
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let tilt = abs(sin(angle * .pi / 180))
        // The shadow reaches further across the page the closer the sheet is to lying on it.
        let reach = max(0.05, 0.6 * (1 - min(1, -angle / 180)))
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.45 * tilt), location: 0),
                .init(color: .black.opacity(0.15 * tilt), location: reach * 0.5),
                .init(color: .clear, location: reach)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
