//
//  Color+Extensions.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import Foundation
import SwiftUI

// MARK: - Adaptive Grid Helper
/// Helper to create adaptive grid columns for responsive layouts
struct AdaptiveGridHelper {
    let horizontalSizeClass: UserInterfaceSizeClass?

    /// Get columns for card collection grids
    func cardGridColumns() -> [GridItem] {
        let count = columnCount(base: 2)
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    /// Get columns for set detail grids
    func setDetailColumns() -> [GridItem] {
        let count = columnCount(base: 3)
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    /// Get columns for deck card grids
    func deckGridColumns() -> [GridItem] {
        let count = columnCount(base: 3)
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    /// Calculate column count based on device and size class
    private func columnCount(base: Int) -> Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            if horizontalSizeClass == .regular {
                // iPad full width - use more columns
                switch base {
                case 2: return 4  // Collection: 2 -> 4
                case 3: return 5  // Set detail: 3 -> 5
                default: return base * 2
                }
            } else {
                // iPad split screen - use moderate columns
                return base + 1  // 2 -> 3, 3 -> 4
            }
        }
        // iPhone uses base columns
        return base
    }

    /// Check if we're on iPad
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Get adaptive spacing for grids
    var gridSpacing: CGFloat {
        isIPad ? 16 : 12
    }

    /// Get adaptive padding for views
    var viewPadding: CGFloat {
        isIPad ? 20 : 16
    }
}

// MARK: - View Extensions
extension View {
    /// Allows conditional application of modifiers
    @ViewBuilder
    func apply<Content: View>(@ViewBuilder transform: (Self) -> Content) -> some View {
        transform(self)
    }
}

extension Color {
    static let lorcanaGold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let lorcanaDark = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let lorcanaBlue = Color(red: 0.2, green: 0.4, blue: 0.8)
    static let lorcanaPurple = Color(red: 0.5, green: 0.2, blue: 0.8)
}
