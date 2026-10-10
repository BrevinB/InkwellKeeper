//
//  RenderedContainerArtwork.swift
//  Inkwell Keeper
//
//  A storage container built from its Blender renders (`Scripts/storage_art`),
//  tinted to the cover color. Layers, back to front:
//
//    1. the whole base, including any open interior
//    2. cards rising out of it (boxes) or heaped in it (bins)
//    3. the base again, cut to its front wall, so cards come up from inside
//    4. the lid, which lifts and tips about its front-left corner
//

import SwiftUI

struct RenderedContainerArtwork: View {
    let kind: StorageKind
    let color: StorageCoverColor
    let style: StorageCoverStyle
    /// 0 = lid closed, 1 = lid lifted with cards peeking out. Boxes only.
    var lidLift: Double = 0

    var body: some View {
        let metrics = RenderedArtworkMetrics.forKind(kind)
        let lift = min(max(lidLift, 0), 1)
        let base = metrics.layerName("base", style: style)
        ZStack {
            TintedRenderLayer(name: base, color: color, style: style)

            if let rimY = metrics.rimY, metrics.cards != .none {
                Group {
                    if metrics.cards == .heap {
                        CardHeap(metrics: metrics)
                    } else {
                        CardsRising(lift: lift, metrics: metrics)
                    }
                }
                // Never let a card show below the box.
                .mask { HorizontalBand(from: 0, to: metrics.bottomY) }

                TintedRenderLayer(name: base, color: color, style: style)
                    .mask { HorizontalBand(from: rimY, to: 1) }
            }

            if let hinge = metrics.lidHinge {
                let rise = metrics.lidRise
                TintedRenderLayer(name: metrics.layerName("lid", style: style), color: color, style: style)
                    .rotationEffect(.degrees(-4 * lift), anchor: hinge)
                    .visualEffect { content, proxy in
                        content.offset(y: -proxy.size.height * rise * lift)
                    }
            }
        }
    }
}

#Preview("Every kind") {
    ScrollView {
        LazyVGrid(columns: [.init(.adaptive(minimum: 150))], spacing: 20) {
            ForEach(StorageKind.allCases) { kind in
                ContainerArtwork(kind: kind, color: .amethyst, style: .classic)
                    .frame(height: 110)
                ContainerArtwork(kind: kind, color: .ruby, style: .leather, lidLift: 1)
                    .frame(height: 110)
            }
        }
        .padding()
    }
    .background(LorcanaBackground())
}

#Preview("Finishes") {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            ContainerArtwork(kind: .binder, color: .sapphire, style: .starlight)
            ContainerArtwork(kind: .binder, color: .emerald, style: .holofoil)
            ContainerArtwork(kind: .binder, color: .ivory, style: .leather)
        }
        .frame(height: 150)
        HStack(spacing: 16) {
            ContainerArtwork(kind: .trove, color: .amethyst, style: .starlight, lidLift: 0.6)
            ContainerArtwork(kind: .deckBox, color: .midnight, style: .holofoil, lidLift: 1)
        }
        .frame(height: 150)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LorcanaBackground())
}
