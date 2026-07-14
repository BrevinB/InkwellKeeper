//
//  CloudSyncBanner.swift
//  Inkwell Keeper
//
//  Small top-of-screen pill shown while iCloud is importing the collection.
//

import SwiftUI

/// A compact pill shown at the top of the app while iCloud is importing the
/// user's collection, so a momentarily empty screen doesn't look broken.
struct CloudSyncBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(.lorcanaGold)
            Text("Syncing with iCloud…")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        // Deliberate pill sizing for a floating status chip.
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay(
            Capsule()
                .strokeBorder(.lorcanaGold.opacity(0.4), lineWidth: 1)
        )
        .shadow(radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Syncing your collection with iCloud")
    }
}

#Preview {
    ZStack {
        Color.lorcanaDark.ignoresSafeArea()
        CloudSyncBanner()
    }
}
