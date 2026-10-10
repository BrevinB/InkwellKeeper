//
//  ContainerArtwork.swift
//  Inkwell Keeper
//
//  Draws a storage container as the physical object it stands for — a ring binder,
//  a trove, a deck box — in the collector's chosen color and finish. Used on the
//  shelf, in the create sheet preview, and as the opening cover of a binder.
//

import SwiftUI

struct ContainerArtwork: View {
    let kind: StorageKind
    let color: StorageCoverColor
    let style: StorageCoverStyle
    /// 0 = lid closed, 1 = lid lifted with cards peeking out. Boxes only.
    var lidLift: Double = 0

    /// Width ÷ height for each kind, so every object keeps believable proportions.
    static func aspectRatio(for kind: StorageKind) -> CGFloat {
        switch kind {
        case .binder: 0.78
        case .trove: 1.2
        case .deckBox: 0.7
        case .storageBox: 1.8
        case .bulkBin: 1.5
        case .other: 1.0
        }
    }

    var body: some View {
        // Pre-rendered in Blender (Scripts/storage_art); see RenderedContainerArtwork.
        RenderedContainerArtwork(kind: kind, color: color, style: style, lidLift: lidLift)
            .aspectRatio(Self.aspectRatio(for: kind), contentMode: .fit)
            .accessibilityHidden(true)
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [.init(.adaptive(minimum: 120))], spacing: 24) {
            ForEach(StorageKind.allCases) { kind in
                ContainerArtwork(kind: kind, color: .amethyst, style: .starlight)
                    .frame(height: 120)
            }
            ForEach(StorageCoverColor.allCases) { color in
                ContainerArtwork(kind: .binder, color: color, style: .leather)
                    .frame(height: 120)
            }
            ContainerArtwork(kind: .trove, color: .ruby, style: .holofoil, lidLift: 1)
                .frame(height: 120)
        }
        .padding()
    }
    .background(LorcanaBackground())
}
