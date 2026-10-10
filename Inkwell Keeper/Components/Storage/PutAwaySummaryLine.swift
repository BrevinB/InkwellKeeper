//
//  PutAwaySummaryLine.swift
//  Inkwell Keeper
//
//  After a scan batch goes into a container: where the cards went, and how many
//  didn't fit (a full binder leaves the rest Unsorted).
//

import SwiftUI

struct PutAwaySummaryLine: View {
    let containerName: String
    let stored: Int
    let leftOver: Int

    var body: some View {
        VStack(spacing: 2) {
            Label("^[\(stored) card](inflect: true) put in \(containerName)", systemImage: "tray.and.arrow.down.fill")
                .foregroundStyle(.lorcanaGold)
            if leftOver > 0 {
                Text("\(leftOver) couldn't go in and stayed in Unsorted")
                    .foregroundStyle(.orange)
            }
        }
        .font(.footnote)
        .accessibilityElement(children: .combine)
    }
}
