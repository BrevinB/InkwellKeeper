//
//  BookTurnView.swift
//  Inkwell Keeper
//
//  A binder turning from spine-on to cover-on, like a book being pulled from a
//  bookcase and turned to face you. The spine and front cover are two faces hinged
//  at their shared edge; as `angle` runs 0 → 90 the spine swings away and the cover
//  swings round to face the viewer. Animatable so the faces track every frame.
//
//  The faces are passed in, so the pull can turn cheap pre-rendered images while
//  previews turn the live artwork.
//

import SwiftUI

struct BookTurnView<Spine: View, Cover: View>: View, Animatable {
    /// 0 = spine facing the viewer, 90 = front cover facing the viewer.
    var angle: Double
    let spineWidth: CGFloat
    let coverWidth: CGFloat
    let height: CGFloat
    let spine: Spine
    let cover: Cover

    init(
        angle: Double,
        spineWidth: CGFloat,
        coverWidth: CGFloat,
        height: CGFloat,
        @ViewBuilder spine: () -> Spine,
        @ViewBuilder cover: () -> Cover
    ) {
        self.angle = angle
        self.spineWidth = spineWidth
        self.coverWidth = coverWidth
        self.height = height
        self.spine = spine()
        self.cover = cover()
    }

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let radians = angle * .pi / 180
        let spineShown = spineWidth * cos(radians)
        let coverShown = coverWidth * sin(radians)

        ZStack {
            spine
                .frame(width: spineWidth, height: height)
                // Turning away from the light as it swings back.
                .overlay { Color.black.opacity(0.45 * sin(radians)) }
                .rotation3DEffect(.degrees(-angle), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.4)
                .offset(x: -spineWidth / 2)
                .opacity(angle < 89 ? 1 : 0)

            cover
                .frame(width: coverWidth, height: height)
                .overlay { Color.black.opacity(0.45 * cos(radians)) }
                .rotation3DEffect(.degrees(90 - angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.4)
                .offset(x: coverWidth / 2)
                .opacity(angle > 1 ? 1 : 0)
        }
        // The hinge sits at the centre of the ZStack; shift so whatever is visible
        // (spine to the left of it, cover to the right) stays centred.
        .offset(x: (spineShown - coverShown) / 2)
        .frame(width: max(1, spineShown + coverShown), height: height)
        .accessibilityHidden(true)
    }
}

/// Frozen frames of a binder being turned from its spine to its cover.
#Preview("Turn frames") {
    // Not inserted anywhere: the turn only needs the binder's name and cover.
    let binder: StorageContainer = {
        let binder = StorageContainer(name: "Main Binder", kind: .binder)
        binder.coverColor = .ruby
        binder.cover = .starlight
        return binder
    }()
    HStack(alignment: .bottom, spacing: 18) {
        ForEach([0.0, 25, 50, 75, 90], id: \.self) { angle in
            VStack {
                BookTurnView(angle: angle, spineWidth: 34, coverWidth: 131, height: 168) {
                    BinderSpineView(name: binder.name, color: binder.coverColor, style: binder.cover)
                } cover: {
                    ClosedBinderCover(container: binder)
                }
                Text("\(Int(angle))°").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LorcanaBackground())
}
