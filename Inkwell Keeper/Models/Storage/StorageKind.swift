//
//  StorageKind.swift
//  Inkwell Keeper
//
//  The kinds of physical storage a collector can mirror in the app.
//

import Foundation

enum StorageKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case binder
    case trove
    case deckBox
    case storageBox
    case bulkBin
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .binder: "Binder"
        case .trove: "Trove"
        case .deckBox: "Deck Box"
        case .storageBox: "Storage Box"
        case .bulkBin: "Bulk Bin"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .binder: "book.closed.fill"
        case .trove: "shippingbox.fill"
        case .deckBox: "rectangle.stack.fill"
        case .storageBox: "archivebox.fill"
        case .bulkBin: "tray.full.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    /// Suggested capacity for new containers of this kind. `nil` means
    /// "no meaningful default" — the collector can still set one.
    var defaultCapacity: Int? {
        switch self {
        case .binder: nil
        case .trove: nil
        case .deckBox: 100
        case .storageBox: 800
        case .bulkBin: nil
        case .other: nil
        }
    }

    /// Binders hold cards in exact pocket positions; everything else is a loose pile.
    var usesSlots: Bool { self == .binder }
}
