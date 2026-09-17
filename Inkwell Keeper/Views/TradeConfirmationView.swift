//
//  TradeConfirmationView.swift
//  Inkwell Keeper
//
//  The moment a trade is agreed: both sides' cards sweep toward each other,
//  cross, and settle as a confirmed trade the collector can share.
//
//  It records nothing — no cards move between collections — because the app
//  cannot know what the other person actually handed over. This marks the
//  handshake and produces something to send, and says so plainly rather than
//  implying the collection has been updated.
//

import SwiftUI

struct TradeConfirmationView: View {
    let yours: TradeSide
    let theirs: TradeSide
    let difference: Double

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .ready
    @State private var showingShare = false

    enum Phase {
        case ready
        case sending
        case done
    }

    private var verdict: String {
        if abs(difference) < 0.01 { return "An even trade" }
        let amount = PricingService.formatPrice(abs(difference))
        return difference > 0 ? "You came out \(amount) ahead" : "You gave up \(amount) in value"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                VStack(spacing: 28) {
                    Spacer()

                    TradeExchangeAnimation(
                        yours: yours.lines,
                        theirs: theirs.lines,
                        phase: phase
                    )

                    VStack(spacing: 8) {
                        Text(phase == .done ? "Trade confirmed" : "Ready to trade?")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.white)

                        Text(phase == .done ? verdict : "\(yours.cardCount) for \(theirs.cardCount)")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    .animation(.easeInOut, value: phase)

                    Spacer()

                    if phase == .done {
                        VStack(spacing: 10) {
                            Button("Share this trade", systemImage: "square.and.arrow.up") {
                                showingShare = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.lorcanaGold)
                            .foregroundStyle(.black)

                            Text("Nothing was added to or removed from your collection.")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Button("Confirm trade", systemImage: "checkmark", action: confirm)
                            .buttonStyle(.borderedProminent)
                            .tint(.lorcanaGold)
                            .foregroundStyle(.black)
                            .disabled(phase == .sending)
                    }
                }
                .padding()
            }
            .navigationTitle("Confirm Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(phase == .done ? "Done" : "Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShare) {
                ShareCardPresenter(
                    analyticsType: "trade",
                    qrPayload: AppLinks.appStoreURLString,
                    fileName: "InkwellKeeper-Trade",
                    canvasHeight: nil,
                    preloadURLs: preloadURLs
                ) { images in
                    TradeShareCardView(
                        yours: yours,
                        theirs: theirs,
                        difference: difference,
                        images: images
                    )
                }
            }
        }
    }

    private var preloadURLs: [String: URL] {
        var urls: [String: URL] = [:]
        for line in yours.lines + theirs.lines {
            if let url = line.card.bestImageUrl() {
                urls[line.id] = url
            }
        }
        return urls
    }

    private func confirm() {
        Analytics.send(.tradeConfirmed(
            yourCards: yours.cardCount,
            theirCards: theirs.cardCount
        ))
        withAnimation(.easeInOut(duration: 0.9)) {
            phase = .sending
        }
        Task {
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                phase = .done
            }
        }
    }
}
