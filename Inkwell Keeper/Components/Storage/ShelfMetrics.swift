//
//  ShelfMetrics.swift
//  Inkwell Keeper
//
//  Shared geometry so every shelf item stands on the same plank.
//

import CoreGraphics

enum ShelfMetrics {
    /// Height of the space above the plank where objects stand.
    static let objectZone: CGFloat = 84
    /// Tallest object drawn in the zone.
    static let objectHeight: CGFloat = 74
    /// Top surface plus front edge of the plank.
    static let plankHeight: CGFloat = 18
    /// How far objects sink into the plank's top surface, so they look like they sit on it.
    static let footing: CGFloat = 5
    static let itemWidth: CGFloat = 96
}
