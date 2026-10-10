//
//  BinderPageScrubber.swift
//  Inkwell Keeper
//
//  Page controls under the binder: previous/next buttons (which animate a turn) and
//  a slider to jump anywhere. The slider is VoiceOver-adjustable.
//

import SwiftUI

struct BinderPageScrubber: View {
    let model: BinderViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button("Previous Page", systemImage: "chevron.left") {
                model.requestTurn(forward: false)
            }
            .labelStyle(.iconOnly)
            .disabled(!model.canGoBack)

            VStack(spacing: 2) {
                Text(model.positionLabel)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.gray)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.position)

                if model.positionCount > 1 {
                    Slider(
                        value: Binding(
                            get: { Double(model.position) },
                            set: { model.position = Int($0.rounded()) }
                        ),
                        in: 0...Double(model.positionCount - 1),
                        step: 1
                    )
                    .accessibilityLabel("Page")
                    .accessibilityValue(model.positionLabel)
                }
            }

            Button("Next Page", systemImage: "chevron.right") {
                model.requestTurn(forward: true)
            }
            .labelStyle(.iconOnly)
            .disabled(!model.canGoForward)
        }
        .font(.title3)
        .tint(.lorcanaGold)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
