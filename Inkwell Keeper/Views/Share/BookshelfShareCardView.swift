//
//  BookshelfShareCardView.swift
//  Inkwell Keeper
//
//  "My Bookshelf" share-card template: a miniature of the collector's real
//  bookcase above what it holds and what it's worth. Presentation-only and
//  rendered off-screen by `ShareImageRenderer` inside `ShareCardChrome`.
//

import SwiftUI

struct BookshelfShareCardView: View {
    let summary: BookshelfShareSummary
    var currencyCode = "USD"

    /// Inner width of the share canvas, minus the bookcase's own side margins.
    private static let shelfWidth = ShareCardLayout.size.width - ShareCardLayout.contentPadding * 2 - 24

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("My")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Bookshelf")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.lorcanaGold)
            }

            MiniBookcase(containers: summary.containers, shelfWidth: Self.shelfWidth)

            HStack(spacing: 0) {
                BookshelfStat(value: Text(summary.binderCount, format: .number), label: "Binders")
                BookshelfStat(value: Text(summary.boxCount, format: .number), label: "Boxes")
                BookshelfStat(value: Text(summary.cardCount, format: .number), label: "Cards")
                if summary.value > 0 {
                    BookshelfStat(
                        value: Text(summary.value, format: .currency(code: currencyCode).precision(.fractionLength(0))),
                        label: "Value"
                    )
                }
            }

            if let showpiece = summary.showpiece {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.lorcanaGold)
                    Text("Showpiece: \(showpiece.name)")
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(showpiece.value, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        .foregroundStyle(.lorcanaGold)
                }
                .font(.caption)
                .bold()
            }
        }
    }
}

#if DEBUG
#Preview("Share card") {
    let fixture = StoragePreviewFixture.shared
    ScrollView {
        ShareCardChrome(qrPayload: AppLinks.appStoreURLString, tagline: "Organize your Lorcana collection", height: nil) {
            BookshelfShareCardView(summary: BookshelfShareSummary(
                containers: fixture.storageManager.containers,
                value: fixture.storageManager.value(of:)
            ))
        }
        .padding()
    }
    .background(LorcanaBackground())
    // The share renderer draws in dark mode.
    .environment(\.colorScheme, .dark)
}
#endif
