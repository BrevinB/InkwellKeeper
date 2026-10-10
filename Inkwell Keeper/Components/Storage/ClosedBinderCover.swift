//
//  ClosedBinderCover.swift
//  Inkwell Keeper
//
//  The front cover shown lying on the pages before the binder swings open: the
//  rendered leather stretched to the page, with the name on its gold label plate.
//

import SwiftUI

struct ClosedBinderCover: View {
    let container: StorageContainer

    var body: some View {
        TintedRenderLayer(
            name: RenderedArtworkMetrics.binderCover.layerName("base", style: container.cover),
            color: container.coverColor,
            style: container.cover
        )
        .overlay {
            BinderCoverOrnaments(name: container.name, trim: container.coverColor.trim)
        }
    }
}

#if DEBUG
#Preview("Page sizes") {
    let fixture = StoragePreviewFixture.shared
    HStack(alignment: .top, spacing: 16) {
        // A 9-pocket page on iPhone, and a wide 12-pocket page on iPad.
        ClosedBinderCover(container: fixture.binder)
            .frame(width: 170, height: 240)
        ClosedBinderCover(container: fixture.binder)
            .frame(width: 200, height: 190)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LorcanaBackground())
}
#endif
