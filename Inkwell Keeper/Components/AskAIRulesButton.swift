//
//  AskAIRulesButton.swift
//  Inkwell Keeper
//
//  Entry point into the AI Rules Assistant from any card surface. Opens the
//  assistant pre-seeded with the card; non-subscribers land on the paywall,
//  which is the discovery funnel for the Pro AI features.
//

import SwiftUI

struct AskAIRulesButton: View {
    let card: LorcanaCard
    /// Where the button lives ("collectionDetail", "deckDetail", …) for funnel analytics.
    let source: String

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingRulesAssistant = false

    var body: some View {
        Button(action: openAssistant) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.lorcanaGold)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Ask About This Card")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.white)

                        if !subscriptionManager.isSubscribed {
                            ProPill()
                        }
                    }

                    Text("Instant AI answers — rulings, interactions, strategy")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.lorcanaGold.opacity(0.6))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaDark.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.lorcanaGold.opacity(0.7), .lorcanaGold.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .accessibilityLabel("Ask about \(card.name)")
        .sheet(isPresented: $showingRulesAssistant) {
            RulesAssistantView(initialCard: card, presentedModally: true)
        }
    }

    private func openAssistant() {
        Analytics.send(.rulesAssistantOpened(source: source))
        showingRulesAssistant = true
    }
}

/// Small badge marking a Pro-gated feature for non-subscribers.
struct ProPill: View {
    var body: some View {
        Text("PRO")
            .font(.caption2)
            .bold()
            .foregroundStyle(.lorcanaDark)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.lorcanaGold))
    }
}
