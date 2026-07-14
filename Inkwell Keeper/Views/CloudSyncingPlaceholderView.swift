//
//  CloudSyncingPlaceholderView.swift
//  Inkwell Keeper
//
//  Shown in the collection while the first iCloud import is still bringing
//  cards down, instead of the "add your first card" empty state.
//

import SwiftUI

/// Full-area state shown in the collection while the initial iCloud import is
/// still downloading cards, so a fresh install doesn't look like it lost data.
struct CloudSyncingPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.lorcanaGold)

            Text("Syncing with iCloud")
                .font(.title3)
                .bold()
                .foregroundStyle(.white)

            Text("Your collection is downloading from iCloud. Cards will appear here as they sync.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Syncing your collection with iCloud. Cards will appear as they download.")
    }
}

#Preview {
    ZStack {
        Color.lorcanaDark.ignoresSafeArea()
        CloudSyncingPlaceholderView()
    }
}
