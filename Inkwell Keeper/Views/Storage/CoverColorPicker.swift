//
//  CoverColorPicker.swift
//  Inkwell Keeper
//
//  A row of cover swatches.
//

import SwiftUI

struct CoverColorPicker: View {
    @Binding var selection: StorageCoverColor

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(StorageCoverColor.allCases) { color in
                    Button {
                        withAnimation(.snappy) { selection = color }
                    } label: {
                        Circle()
                            .fill(LinearGradient(colors: [color.highlight, color.shadow], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 34, height: 34)
                            .overlay {
                                Circle()
                                    .stroke(Color.lorcanaGold, lineWidth: selection == color ? 3 : 0)
                                    .padding(-4)
                            }
                            .scaleEffect(selection == color ? 1.08 : 1)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.displayName)
                    .accessibilityAddTraits(selection == color ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}
