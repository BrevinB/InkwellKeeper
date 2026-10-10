//
//  BinderInsideCover.swift
//  Inkwell Keeper
//
//  The inside of the front cover: the binder's name plate and its numbers.
//

import SwiftUI

struct BinderInsideCover: View {
    let container: StorageContainer
    let value: Double
    /// For set binders: (collected, total) card numbers.
    let setProgress: (filled: Int, total: Int)?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [container.coverColor.shadow, container.coverColor.shadow.opacity(0.75)],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .overlay {
                    CoverFinishOverlay(style: container.cover, color: container.coverColor)
                        .clipShape(.rect(cornerRadius: 8))
                        .opacity(0.5)
                }

            VStack(spacing: 10) {
                SparkleShape()
                    .fill(container.coverColor.trim)
                    .frame(width: 26, height: 26)

                Text(container.name)
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(container.coverColor.trim)
                    .minimumScaleFactor(0.6)

                Divider()
                    .overlay(container.coverColor.trim.opacity(0.4))
                    .padding(.horizontal, 24)

                VStack(spacing: 4) {
                    Text("^[\(container.cardCount) card](inflect: true)")
                    if value > 0 {
                        Text(value, format: .currency(code: "USD"))
                    }
                    if let setProgress {
                        Text("\(setProgress.filled) of \(setProgress.total) in set")
                        ProgressView(value: Double(setProgress.filled), total: Double(max(1, setProgress.total)))
                            .tint(.lorcanaGold)
                            .padding(.horizontal, 24)
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding()
        }
        .accessibilityElement(children: .combine)
    }
}
