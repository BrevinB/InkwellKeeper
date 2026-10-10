//
//  FullBadge.swift
//  Inkwell Keeper
//
//  Marks a binder or box that has no room left.
//

import SwiftUI

struct FullBadge: View {
    var body: some View {
        Text("FULL")
            .font(.caption2)
            .bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.orange))
            .accessibilityLabel("Full")
    }
}
