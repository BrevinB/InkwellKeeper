//
//  BookcaseLayout.swift
//  Inkwell Keeper
//
//  How the Bookshelf tab arranges containers: binders stand spine-out side by
//  side, boxes sit face-out after them, and a shelf that fills up wraps onto the
//  next one down.
//

import CoreGraphics

enum BookcaseLayout {
    /// The tallest thing a shelf holds: a binder standing on end.
    static let spineHeight: CGFloat = 168
    /// Width ÷ height of the rendered spine at its default thickness.
    static let spineAspect: CGFloat = 0.2
    /// Books stand nearly touching; boxes get breathing room.
    static let spineGap: CGFloat = 2
    static let objectGap: CGFloat = 18

    /// One object on a shelf, as far as layout cares.
    struct Slot: Equatable {
        let width: CGFloat
        let isSpine: Bool
    }

    /// Binders first, then boxes, each keeping the collector's shelf order.
    static func ordered(_ containers: [StorageContainer]) -> [StorageContainer] {
        containers.filter { $0.kind == .binder } + containers.filter { $0.kind != .binder }
    }

    /// Bigger binders have thicker spines, within reason.
    static func spineWidth(sheetCount: Int) -> CGFloat {
        let thickness = min(1.5, max(0.75, 0.7 + Double(sheetCount) / 60))
        return spineHeight * spineAspect * thickness
    }

    /// How tall each kind of box stands; its width follows the artwork's proportions.
    static func objectHeight(for kind: StorageKind) -> CGFloat {
        switch kind {
        case .binder: spineHeight
        case .trove: 104
        case .deckBox: 136
        case .storageBox: 74
        case .bulkBin: 92
        case .other: 108
        }
    }

    static func slot(for container: StorageContainer) -> Slot {
        if container.kind == .binder {
            return Slot(width: spineWidth(sheetCount: container.sheetCount), isSpine: true)
        }
        let height = objectHeight(for: container.kind)
        return Slot(width: height * ContainerArtwork.aspectRatio(for: container.kind), isSpine: false)
    }

    /// The space between two neighbours on a shelf.
    static func gap(between left: Slot, and right: Slot) -> CGFloat {
        left.isSpine && right.isSpine ? spineGap : objectGap
    }

    /// Splits slots into shelves no wider than `availableWidth`, in order. An object
    /// too wide for any shelf still gets one to itself.
    static func rows(for slots: [Slot], availableWidth: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        var used: CGFloat = 0
        for (index, slot) in slots.enumerated() {
            if let last = current.last {
                let needed = gap(between: slots[last], and: slot) + slot.width
                if used + needed > availableWidth {
                    rows.append(current)
                    current = [index]
                    used = slot.width
                } else {
                    current.append(index)
                    used += needed
                }
            } else {
                current = [index]
                used = slot.width
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    /// A bookcase shrunk to fit a fixed space, like the share card's.
    struct Fitted: Equatable {
        /// How much smaller than the Bookshelf tab everything is drawn.
        let scale: CGFloat
        /// The shelves that fit, as indices into the slots.
        let rows: [[Int]]
        /// Objects that didn't fit even at the smallest scale.
        let overflow: Int
    }

    /// The largest scale (from `largest` down to `smallest`) at which every object fits
    /// on `maxRows` shelves of `availableWidth`. If even the smallest scale can't fit
    /// them all, the first `maxRows` shelves are kept and the rest counted as overflow.
    static func fitted(
        _ slots: [Slot],
        availableWidth: CGFloat,
        maxRows: Int,
        largest: CGFloat = 0.62,
        smallest: CGFloat = 0.36
    ) -> Fitted {
        var scale = largest
        while true {
            // Shrinking everything by `scale` is the same as widening the shelf by 1/scale.
            let shelves = rows(for: slots, availableWidth: availableWidth / scale)
            if shelves.count <= maxRows {
                return Fitted(scale: scale, rows: shelves, overflow: 0)
            }
            if scale - 0.02 < smallest {
                let kept = Array(shelves.prefix(maxRows))
                return Fitted(scale: scale, rows: kept, overflow: slots.count - kept.joined().count)
            }
            scale -= 0.02
        }
    }
}
