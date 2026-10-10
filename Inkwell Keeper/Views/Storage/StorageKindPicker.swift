//
//  StorageKindPicker.swift
//  Inkwell Keeper
//
//  Horizontal chips for choosing binder / trove / deck box / etc.
//

import SwiftUI

struct StorageKindPicker: View {
    @Binding var selection: StorageKind

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(StorageKind.allCases) { kind in
                    Button {
                        withAnimation(.snappy) { selection = kind }
                    } label: {
                        StorageChip(title: kind.displayName, systemImage: kind.systemImage, isSelected: selection == kind)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == kind ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
