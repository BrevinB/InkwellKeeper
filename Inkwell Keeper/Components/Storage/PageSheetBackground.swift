//
//  PageSheetBackground.swift
//  Inkwell Keeper
//
//  A clear plastic binder sheet, also used for the bare back of a turning page.
//

import SwiftUI

struct PageSheetBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.2), Color(white: 0.11)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
            .accessibilityHidden(true)
    }
}
