//
//  TintedRenderLayer.swift
//  Inkwell Keeper
//
//  One pre-rendered layer of container artwork, tinted to the cover color.
//
//  The renders come from `Scripts/storage_art` as a pair: `<name>_shade` (the lit
//  object with near-white leather) and `<name>_mask` (opaque where the leather is).
//  Multiplying the cover color over the shade inside the mask colors the leather
//  while keeping the lighting, grain and gold trim from the render.
//

import SwiftUI

struct TintedRenderLayer: View {
    let name: String
    let color: StorageCoverColor
    let style: StorageCoverStyle

    var body: some View {
        Image("\(name)_shade")
            .resizable()
            .overlay {
                color.highlight
                    .mask { Image("\(name)_mask").resizable() }
                    .blendMode(.multiply)
            }
            .compositingGroup()
            .overlay {
                // The Pro finishes sit on the leather only, never the trim.
                if style == .starlight || style == .holofoil {
                    CoverFinishOverlay(style: style, color: color)
                        .mask { Image("\(name)_mask").resizable() }
                        .allowsHitTesting(false)
                }
            }
    }
}
