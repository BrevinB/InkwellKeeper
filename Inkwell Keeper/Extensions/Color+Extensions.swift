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
        columns(phoneCount: 2, minimumWidth: 160, spacing: 16)
    }

    /// Get columns for set detail grids
    func setDetailColumns() -> [GridItem] {
        columns(phoneCount: 3, minimumWidth: 140, spacing: 12)
    }

    /// Get columns for deck card grids
    func deckGridColumns() -> [GridItem] {
        columns(phoneCount: 3, minimumWidth: 140, spacing: 8)
    }

    /// Let the actual container width decide density, including sheets and resized windows.
    private func columns(phoneCount: Int, minimumWidth: CGFloat, spacing: CGFloat) -> [GridItem] {
        if isIPad {
            return [GridItem(.adaptive(minimum: minimumWidth), spacing: spacing)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: phoneCount)
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

/// Bridges the custom palette into `ShapeStyle` contexts so the leading-dot syntax
/// (e.g. `foregroundStyle(.lorcanaGold)`, `fill(.lorcanaDark)`) resolves like the system colors do.
extension ShapeStyle where Self == Color {
    static var lorcanaGold: Color { .lorcanaGold }
    static var lorcanaDark: Color { .lorcanaDark }
    static var lorcanaBlue: Color { .lorcanaBlue }
    static var lorcanaPurple: Color { .lorcanaPurple }
}
