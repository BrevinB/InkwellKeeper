//
//  StorageCoverStyle.swift
//  Inkwell Keeper
//
//  Finishes for binder covers and boxes. Two are free; the showier ones are Pro.
//

import Foundation

enum StorageCoverStyle: String, CaseIterable, Identifiable, Sendable {
    case classic
    case leather
    case starlight
    case holofoil

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .leather: "Stitched"
        case .starlight: "Starlight"
        case .holofoil: "Holofoil"
        }
    }

    var requiresPro: Bool {
        switch self {
        case .classic, .leather: false
        case .starlight, .holofoil: true
        }
    }
}
