//
//  CoverStylePicker.swift
//  Inkwell Keeper
//
//  Finish choices; Pro finishes show a PRO pill and open the paywall for free users.
//

import SwiftUI

struct CoverStylePicker: View {
    @Binding var selection: StorageCoverStyle
    let isSubscribed: Bool
    let onLocked: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(StorageCoverStyle.allCases) { style in
                    let locked = style.requiresPro && !isSubscribed
                    Button {
                        if locked {
                            onLocked()
                        } else {
                            withAnimation(.snappy) { selection = style }
                        }
                    } label: {
                        StorageChip(title: style.displayName, isSelected: selection == style, showsProPill: locked)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == style ? .isSelected : [])
                    .accessibilityHint(locked ? "Requires Inkwell Pro" : "")
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
