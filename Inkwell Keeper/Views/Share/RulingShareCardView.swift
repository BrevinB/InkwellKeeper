//
//  RulingShareCardView.swift
//  Inkwell Keeper
//
//  Share-card template for a Rules Assistant ruling: the question, the answer excerpt, and
//  the card(s) it was about — for settling rules arguments in Discord and group chats.
//  Presentation-only; rendered off-screen by `ShareImageRenderer`.
//

import SwiftUI
import UIKit

/// Everything needed to render a shareable ruling.
struct RulingShareData: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let cards: [RulesMessage.AttachedCard]

    /// Artwork to preload, keyed by card id for the template.
    var preloadURLs: [String: URL] {
        var urls: [String: URL] = [:]
        for card in cards.prefix(2) {
            if let url = URL(string: card.imageUrl) {
                urls[card.id] = url
            }
        }
        return urls
    }
}

struct RulingShareCardView: View {
    let ruling: RulingShareData
    let images: [String: UIImage]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "book.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.lorcanaGold)

                Text("RULES ASSISTANT")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.lorcanaGold)
                    .kerning(1.2)

                Spacer()
            }

            HStack(alignment: .top, spacing: 12) {
                if !cardImages.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(cardImages, id: \.0) { _, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 96)
                                .clipShape(.rect(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.lorcanaGold.opacity(0.6), lineWidth: 1)
                                )
                        }
                    }
                }

                Text(ruling.question)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Rectangle()
                .fill(Color.lorcanaGold.opacity(0.4))
                .frame(height: 1)

            Text(answerExcerpt)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(11)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var cardImages: [(String, UIImage)] {
        ruling.cards.prefix(2).compactMap { card in
            images[card.id].map { (card.id, $0) }
        }
    }

    /// The answer with markdown syntax stripped down for the static image. Bullet markers are
    /// only converted at line starts so hyphens inside card names survive.
    private var answerExcerpt: String {
        ruling.answer
            .components(separatedBy: "\n")
            .map { line in
                var stripped = line.trimmingCharacters(in: .whitespaces)
                for prefix in ["### ", "## ", "# "] where stripped.hasPrefix(prefix) {
                    stripped = String(stripped.dropFirst(prefix.count))
                }
                for prefix in ["- ", "* "] where stripped.hasPrefix(prefix) {
                    stripped = "• " + stripped.dropFirst(prefix.count)
                }
                return stripped.replacing("**", with: "")
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
