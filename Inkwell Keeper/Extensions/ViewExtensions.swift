//
//  ViewExtensions.swift
//  Inkwell Keeper
//
//  Helpful view extensions
//

import SwiftUI

extension View {
    /// Applies a transformation to the view conditionally
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
