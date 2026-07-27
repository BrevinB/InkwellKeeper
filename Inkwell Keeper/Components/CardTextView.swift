//
//  CardTextView.swift
//  Inkwell Keeper
//
//  Renders card rules text with inline game symbols in place of the data's
//  {E}/{I}/{S}/{W}/{L}/{IW} tokens, plus numbered ink costs like {2}.
//

import SwiftUI

/// A game symbol embedded in card text as a `{X}` token.
enum CardTextSymbol: String, CaseIterable {
    case exert = "E"
    case ink = "I"
    case strength = "S"
    case willpower = "W"
    case lore = "L"
    case inkwell = "IW"

    /// Custom symbol asset name (bundled from the MIT-licensed
    /// glimmerdb/lorcana-icons set, drawn by Nate of the Cards).
    var assetName: String {
        switch self {
        case .exert: "lorcana.exert"
        case .ink: "lorcana.ink"
        case .strength: "lorcana.strength"
        case .willpower: "lorcana.willpower"
        case .lore: "lorcana.lore"
        case .inkwell: "lorcana.inkwell"
        }
    }

    /// VoiceOver reading for the token.
    var spokenName: String {
        switch self {
        case .exert: "exert"
        case .ink: "ink"
        case .strength: "strength"
        case .willpower: "willpower"
        case .lore: "lore"
        case .inkwell: "inkwell"
        }
    }
}

/// One parsed run of card text: literal text, a symbol, or a numbered ink cost.
enum CardTextSegment: Equatable {
    case text(String)
    case symbol(CardTextSymbol)
    case inkCost(Int)
}

enum CardTextParser {
    /// Split card text into literal runs and symbol tokens.
    /// Unrecognized `{...}` tokens are kept as literal text.
    static func parse(_ text: String) -> [CardTextSegment] {
        var segments: [CardTextSegment] = []
        var current = ""
        var rest = Substring(text)

        while let open = rest.firstIndex(of: "{"),
              let close = rest[open...].firstIndex(of: "}") {
            let token = String(rest[rest.index(after: open)..<close])

            let replacement: CardTextSegment?
            if let symbol = CardTextSymbol(rawValue: token) {
                replacement = .symbol(symbol)
            } else if let number = Int(token) {
                replacement = .inkCost(number)
            } else {
                replacement = nil
            }

            if let replacement {
                current += rest[..<open]
                if !current.isEmpty {
                    segments.append(.text(current))
                    current = ""
                }
                segments.append(replacement)
            } else {
                current += rest[..<rest.index(after: close)]
            }
            rest = rest[rest.index(after: close)...]
        }

        current += rest
        if !current.isEmpty {
            segments.append(.text(current))
        }
        return segments
    }

    /// The full text with tokens replaced by their spoken names, for VoiceOver.
    static func spokenText(_ text: String) -> String {
        parse(text).map { segment in
            switch segment {
            case .text(let literal): literal
            case .symbol(let symbol): symbol.spokenName
            case .inkCost(let number): "\(number) ink"
            }
        }.joined()
    }
}

/// Card rules text with game symbols rendered inline, wrapping as one text flow.
struct CardTextView: View {
    let text: String

    var body: some View {
        CardTextParser.parse(text)
            .reduce(Text("")) { partial, segment in
                Text("\(partial)\(segmentText(segment))")
            }
            .accessibilityLabel(CardTextParser.spokenText(text))
    }

    private func segmentText(_ segment: CardTextSegment) -> Text {
        switch segment {
        case .text(let literal):
            Text(literal)
        case .symbol(let symbol):
            Text("\(Image(symbol.assetName))")
        case .inkCost(let number):
            Text("\(number)\(Image(CardTextSymbol.ink.assetName))")
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        CardTextView(text: "SWEET TECH {2} {E} - Search your deck for an item card.")
        CardTextView(text: "Evasive (Only characters with Evasive can challenge this character.) This character gets +2 {S} and +1 {L}.")
        CardTextView(text: "All cards in your hand count as having {IW}.")
    }
    .padding()
    .background(Color.black)
    .foregroundStyle(.white)
}
