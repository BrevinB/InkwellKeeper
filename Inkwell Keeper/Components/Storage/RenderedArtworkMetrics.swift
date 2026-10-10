//
//  RenderedArtworkMetrics.swift
//  Inkwell Keeper
//
//  Where the parts of a pre-rendered container land in its frame, as fractions of
//  the frame's size with a top-left origin. The values are measured by the Blender
//  script and generated into `RenderedArtworkMetrics+Generated.swift`.
//

import SwiftUI

struct RenderedArtworkMetrics {
    enum Cards {
        /// Nothing peeks out (binders).
        case none
        /// A fan of cards rises out as the lid lifts.
        case rising
        /// An open bin heaped with loose cards.
        case heap
    }

    /// Asset name prefix, e.g. "trove" for `trove_base_classic_shade`.
    let prefix: String
    /// The bottom of the object's front face.
    let bottomY: CGFloat
    /// The front rim of an open box; everything below it is the front wall.
    var rimY: CGFloat?
    /// The inside edges of the opening.
    var openingLeft: CGFloat = 0
    var openingRight: CGFloat = 1
    /// The lid's front-left bottom corner, which it tips about.
    var lidHinge: UnitPoint?
    /// How far the lid rises when fully lifted.
    var lidRise: CGFloat = 0
    /// Where the middle card's top reaches when the lid is fully lifted.
    var cardPeakY: CGFloat = 0
    /// Card width as a fraction of the frame's width.
    var cardWidth: CGFloat = 0
    /// Where a name goes (the binder spine's label holder).
    var label: CGRect?

    var cards: Cards {
        guard rimY != nil, cardWidth > 0 else { return .none }
        return lidHinge == nil ? .heap : .rising
    }

    /// The asset name for one part in one finish; the Stitched cover has its own render.
    func layerName(_ part: String, style: StorageCoverStyle) -> String {
        "\(prefix)_\(part)_\(style == .leather ? "stitched" : "classic")"
    }

    static func forKind(_ kind: StorageKind) -> Self {
        switch kind {
        case .binder: .binder
        case .trove: .trove
        case .deckBox: .deckBox
        case .storageBox: .storageBox
        case .bulkBin: .bulkBin
        case .other: .other
        }
    }
}
