//
//  BinderCoverOrnaments.swift
//  Inkwell Keeper
//
//  The gold label plate, the binder's name on it, and the sparkle emblem, placed on
//  the rendered cover. The cover stretches to fit the page; the ornaments keep their
//  proportions and stay where the render put them.
//

import SwiftUI

struct BinderCoverOrnaments: View {
    let name: String
    let trim: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let plate = RenderedArtworkMetrics.coverPlate
            let emblem = RenderedArtworkMetrics.coverEmblem
            let plateWidth = size.width * plate.width

            ZStack {
                Image("bindercover_plate")
                    .resizable()
                    .scaledToFit()
                    .frame(width: plateWidth)
                    .overlay {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(trim)
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, plateWidth * 0.08)
                            .padding(.vertical, 4)
                    }
                    .position(x: size.width * plate.midX, y: size.height * plate.midY)

                Image("bindercover_emblem")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * emblem.width)
                    .position(x: size.width * emblem.midX, y: size.height * emblem.midY)
            }
        }
    }
}
