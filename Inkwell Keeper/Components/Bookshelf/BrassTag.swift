//
//  BrassTag.swift
//  Inkwell Keeper
//
//  A small engraved brass plate fixed to the shelf edge under a box, naming it.
//

import SwiftUI

struct BrassTag: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.caption2)
            .bold()
            .lineLimit(1)
            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0.06))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background {
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.98, green: 0.84, blue: 0.5), Color(red: 0.72, green: 0.52, blue: 0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .overlay { Capsule().strokeBorder(.black.opacity(0.25), lineWidth: 0.5) }
                    .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
            }
            .accessibilityHidden(true)
    }
}
