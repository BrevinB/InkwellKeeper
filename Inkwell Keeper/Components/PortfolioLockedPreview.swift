//
//  PortfolioLockedPreview.swift
//  Inkwell Keeper
//
//  What non-subscribers see in place of the value chart: their own history,
//  blurred, with the figures withheld.
//
//  It plots the reader's real series rather than an illustrative one. An
//  invented sample would have to pick a direction, and a rising green preview
//  in front of a collection that is actually down promises a gain the product
//  cannot deliver — the kind of claim that earns a refund and a one-star
//  review. Blurring the reader's own line keeps the pitch honest in either
//  direction: they see the shape, and unlocking buys the numbers.
//

import SwiftUI
import Charts

struct PortfolioLockedPreview: View {
    let points: [PortfolioPoint]
    /// Start of the charted window, used only to date the pitch.
    let since: Date?
    let onUnlock: () -> Void

    init(points: [PortfolioPoint], since: Date?, onUnlock: @escaping () -> Void) {
        self.points = points
        self.since = since
        self.onUnlock = onUnlock
    }

    /// Falls back to wording that needs no date, so a failed fetch never puts
    /// a wrong month on screen.
    private var pitch: String {
        guard let since else {
            return "See every rise and dip in your collection's value, and what changed this week."
        }
        let month = since.formatted(.dateTime.month(.wide).year())
        return "Every rise and dip since \(month), and what changed this week."
    }

    var body: some View {
        ZStack {
            Group {
                if points.count >= 2 {
                    PortfolioValueChart(points: points, showsAxes: false, lineWidth: 3)
                        // Swift Charts builds its own accessibility tree and
                        // narrates each mark's value, so collapse it here as
                        // well as hiding the container: the locked card must
                        // not read out figures it does not show.
                        .accessibilityElement(children: .ignore)
                        .accessibilityHidden(true)
                        .blur(radius: 2)
                        .opacity(0.8)
                        // A scrim keeps the overlay readable whatever the line
                        // is doing underneath — the copy would otherwise sit
                        // on bare chart fill, which is the lowest-contrast
                        // text on the screen.
                        .overlay(Color.lorcanaDark.opacity(0.45))
                } else {
                    // Nothing of the reader's own to show yet, so the space
                    // stays empty rather than being filled with a shape that
                    // would read as their data.
                    Color.clear.frame(height: 180)
                }
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.largeTitle)
                    .foregroundStyle(.lorcanaGold)

                Text("See what your collection is worth over time")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(pitch)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                Button("Unlock with Pro", systemImage: "sparkles", action: onUnlock)
                    .buttonStyle(.borderedProminent)
                    .tint(.lorcanaGold)
                    .foregroundStyle(.black)
            }
            .padding()
        }
    }
}
