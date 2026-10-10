//
//  CoverFinishOverlay.swift
//  Inkwell Keeper
//
//  The surface finish on a binder or box: a soft sheen, stitching, twinkling
//  starlight, or a holofoil sheen. Starlight's twinkle stops when Reduce Motion is on.
//

import SwiftUI

struct CoverFinishOverlay: View {
    let style: StorageCoverStyle
    let color: StorageCoverColor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Every finish gets the same glossy top-left sheen.
            LinearGradient(
                colors: [.white.opacity(0.28), .clear, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            switch style {
            case .classic:
                EmptyView()
            case .leather:
                LeatherStitching(color: color)
            case .starlight:
                StarlightFinish(animated: !reduceMotion)
            case .holofoil:
                HolofoilFinish()
            }
        }
    }
}
