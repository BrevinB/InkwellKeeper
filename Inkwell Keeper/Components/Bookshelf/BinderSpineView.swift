//
//  BinderSpineView.swift
//  Inkwell Keeper
//
//  A binder seen spine-on, as it stands on the bookcase: the rendered spine in the
//  cover color and finish, with the binder's name running down its gold label.
//

import SwiftUI

struct BinderSpineView: View {
    let name: String
    let color: StorageCoverColor
    let style: StorageCoverStyle

    var body: some View {
        TintedRenderLayer(
            name: RenderedArtworkMetrics.binderSpine.layerName("base", style: style),
            color: color,
            style: style
        )
        .overlay {
            GeometryReader { proxy in
                let label = RenderedArtworkMetrics.binderSpine.label ?? .zero
                let rect = CGRect(
                    x: label.minX * proxy.size.width,
                    y: label.minY * proxy.size.height,
                    width: label.width * proxy.size.width,
                    height: label.height * proxy.size.height
                )
                // Laid out along the spine, then turned to read top to bottom.
                Text(verbatim: name)
                    .font(.caption)
                    .bold()
                    .foregroundStyle(color.trim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(width: rect.height * 0.92, height: rect.width * 0.86)
                    .rotationEffect(.degrees(90))
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }
}

#Preview {
    HStack(alignment: .bottom, spacing: 2) {
        BinderSpineView(name: "Main Binder", color: .ruby, style: .classic)
            .frame(width: 34, height: 168)
        BinderSpineView(name: "Winterspell Master Set", color: .sapphire, style: .leather)
            .frame(width: 46, height: 168)
        BinderSpineView(name: "Trades", color: .ivory, style: .starlight)
            .frame(width: 28, height: 168)
    }
    .padding()
    .background(LorcanaBackground())
}
