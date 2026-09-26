//
//  AIDeckFeedbackPrompt.swift
//  Inkwell Keeper
//
//  "How's this deck?" thumbs up/down under AI deck results. A thumbs down asks for a reason
//  so ratings say what to fix, not just that something missed. Reset it per result by
//  giving it `.id(service.generationID)`.
//

import SwiftUI

struct AIDeckFeedbackPrompt: View {
    /// "build", "complete", "improve" or "strategy".
    let mode: String
    let format: DeckFormat
    var ruleIssues = 0
    var question = "How's this deck?"
    /// Whether these results came from a previous "Try again".
    var isRetry = false
    /// When set, a thumbs down offers to regenerate using the chosen reason.
    var onRetry: ((AIDeckFeedbackReason) -> Void)?

    private enum Stage: Equatable {
        case asking, choosingReason, thanked(AIDeckFeedbackReason?)
    }

    @State private var stage = Stage.asking

    var body: some View {
        VStack(spacing: 10) {
            switch stage {
            case .asking:
                Text(question)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                HStack {
                    Button("Good", systemImage: "hand.thumbsup") {
                        send(helpful: true, reason: nil)
                    }
                    Button("Needs work", systemImage: "hand.thumbsdown") {
                        withAnimation { stage = .choosingReason }
                    }
                }
                .buttonStyle(.bordered)
                .tint(Color.lorcanaGold)

            case .choosingReason:
                Text("What missed?")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                FlowingReasonButtons { reason in
                    send(helpful: false, reason: reason)
                }

            case .thanked(let reason):
                Label("Thanks — this helps improve the AI.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                if let reason, let onRetry {
                    Button("Try again with this feedback", systemImage: "arrow.counterclockwise") {
                        onRetry(reason)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.lorcanaGold)
                    .foregroundStyle(.black)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.lorcanaDark.opacity(0.6), in: .rect(cornerRadius: 12))
        .padding(.horizontal)
        .sensoryFeedback(.selection, trigger: stage != .asking && stage != .choosingReason)
        .onDisappear {
            // A thumbs down without a reason is still a signal worth keeping.
            if stage == .choosingReason {
                report(helpful: false, reason: "unspecified")
            }
        }
    }

    private func send(helpful: Bool, reason: AIDeckFeedbackReason?) {
        report(helpful: helpful, reason: reason?.rawValue ?? "none")
        withAnimation { stage = .thanked(reason) }
    }

    private func report(helpful: Bool, reason: String) {
        Analytics.send(.aiDeckRated(
            mode: mode, helpful: helpful, reason: reason,
            format: format.rawValue, ruleIssues: ruleIssues, retry: isRetry
        ))
    }
}

/// The thumbs-down reason chips: one row when they fit, stacked otherwise (Dynamic Type,
/// narrow phones).
private struct FlowingReasonButtons: View {
    let onSelect: (AIDeckFeedbackReason) -> Void

    var body: some View {
        ViewThatFits {
            HStack {
                ReasonChips(onSelect: onSelect)
            }
            VStack {
                ReasonChips(onSelect: onSelect)
            }
        }
    }
}

private struct ReasonChips: View {
    let onSelect: (AIDeckFeedbackReason) -> Void

    var body: some View {
        ForEach(AIDeckFeedbackReason.allCases) { reason in
            Button(reason.title) {
                onSelect(reason)
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(reason == .brokeRules ? Color.red : Color.lorcanaGold)
        }
    }
}
