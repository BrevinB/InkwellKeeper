//
//  PageLeaf.swift
//  Inkwell Keeper
//
//  One turning binder sheet. `angle` runs from 0 (lying flat on the right) to −180
//  (lying flat on the left), rotating about the spine on the leaf's leading edge.
//
//  The view is Animatable so SwiftUI interpolates `angle` frame by frame; that lets
//  the front face hand over to the back face exactly as the sheet passes edge-on,
//  and lets the shading follow the turn rather than jumping to its end state.
//

import SwiftUI

struct PageLeaf<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let front: Front
    let back: Back
    /// One-page mode has no left page for the sheet to land on. Instead of showing its
    /// back as a phantom spread (and then snapping it away), the sheet fades out as it
    /// reaches edge-on — it reads as turning up and away.
    var fadesAfterEdgeOn = false

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    /// 0 when flat, 1 when edge-on.
    private var tilt: Double { abs(sin(angle * .pi / 180)) }
    /// 0 lying on the right, 1 lying on the left.
    private var progress: Double { min(1, max(0, -angle / 180)) }
    private var showsBack: Bool { angle < -90 }

    /// When fading, the sheet dissolves over the last stretch before edge-on (−70° to
    /// −95°), so it's gone before its back could swing out as a phantom left page.
    private var leafOpacity: Double {
        guard fadesAfterEdgeOn else { return 1 }
        return min(1, max(0, (angle + 95) / 25))
    }

    var body: some View {
        ZStack {
            front
                .opacity(showsBack ? 0 : 1)
            back
                // Pre-flip the back so it reads correctly once the sheet has turned over.
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsBack ? 1 : 0)
        }
        .overlay {
            // The sheet darkens as it turns away from the light, with a glossy band
            // sliding steadily across the plastic as it turns.
            ZStack {
                Color.black.opacity(0.4 * tilt)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.22 * tilt), location: 0.5),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: UnitPoint(x: progress * 1.3 - 0.3, y: 0),
                    endPoint: UnitPoint(x: progress * 1.3, y: 1)
                )
            }
            .allowsHitTesting(false)
        }
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            anchor: .leading,
            perspective: 0.35
        )
        // The drop shadow swings from one side to the other smoothly with the turn.
        .shadow(color: .black.opacity(0.35 * tilt), radius: 12 * tilt, x: -8 * cos(angle * .pi / 180))
        .opacity(leafOpacity)
    }
}

#if DEBUG
/// Frozen frames of a one-page turn: flat, lifting, edge-on, past edge-on, nearly gone.
#Preview("Turn frames – one page") {
    VStack(spacing: 18) {
        ForEach([0.0, -45, -70, -85, -100], id: \.self) { angle in
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.teal.opacity(0.6))
                    .overlay { Text("Next page").foregroundStyle(.white) }
                LeafCastShadow(angle: angle)
                PageLeaf(
                    angle: angle,
                    front: RoundedRectangle(cornerRadius: 8).fill(Color.orange)
                        .overlay { Text("Page 1  \(Int(angle))°").foregroundStyle(.white) },
                    back: PageSheetBackground(),
                    fadesAfterEdgeOn: true
                )
            }
            .frame(width: 150, height: 110)
        }
    }
    .padding(40)
    .frame(maxWidth: .infinity)
    .background(LorcanaBackground())
}
#endif
