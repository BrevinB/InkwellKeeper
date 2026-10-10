//
//  BinderRings.swift
//  Inkwell Keeper
//
//  Three metal rings drawn down the spine of an open binder.
//

import SwiftUI

struct BinderRings: View {
    var body: some View {
        VStack {
            ForEach(0..<3, id: \.self) { _ in
                Spacer()
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.95), Color(white: 0.55), Color(white: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 22, height: 9)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                Spacer()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
