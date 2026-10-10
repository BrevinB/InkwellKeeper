//
//  HorizontalBand.swift
//  Inkwell Keeper
//
//  A full-width band between two heights, for masking one strip of a layer.
//

import SwiftUI

struct HorizontalBand: Shape {
    /// Top and bottom of the band, from 0 (top) to 1 (bottom).
    var from: CGFloat
    var to: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY + rect.height * from, width: rect.width, height: rect.height * (to - from)))
    }
}
