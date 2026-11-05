//
//  PriceAlertTargetPanel.swift
//  Inkwell Keeper
//
//  Where the target price is set: a big number to type into, step buttons,
//  10/20/30% quick picks and the price history with a draggable target line.
//

import SwiftUI

struct PriceAlertTargetPanel: View {
    @Bindable var model: PriceAlertEditorModel
    @FocusState private var isEditingPrice: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Alert me at")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Spacer()
                if let distance = model.distanceFromCurrent {
                    PriceAlertDistanceBadge(distance: distance)
                }
            }

            HStack(spacing: 12) {
                PriceAlertNudgeButton(up: false) { model.nudge(up: false) }
                    .disabled(model.threshold <= PriceAlertRules.roundingStep(for: 0))

                TextField(
                    "Target price",
                    value: Binding(
                        get: { model.threshold },
                        set: { model.setThreshold($0, snapping: false) }
                    ),
                    format: .currency(code: "USD")
                )
                .keyboardType(.decimalPad)
                .focused($isEditingPrice)
                .font(.system(.largeTitle, design: .rounded).bold())
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(model.direction.tint)
                .minimumScaleFactor(0.6)

                PriceAlertNudgeButton(up: true) { model.nudge(up: true) }
            }

            if !model.presets.isEmpty {
                HStack(spacing: 8) {
                    ForEach(model.presets, id: \.distance) { preset in
                        PriceAlertPresetChip(
                            distance: preset.distance,
                            price: preset.price,
                            direction: model.direction,
                            isSelected: abs(model.threshold - preset.price) < 0.005
                        ) {
                            withAnimation(.snappy) { model.setThreshold(preset.price, snapping: false) }
                        }
                    }
                }
            }

            if model.history.count >= 2 {
                VStack(alignment: .leading, spacing: 6) {
                    PriceAlertTargetChart(
                        points: model.history,
                        threshold: model.threshold,
                        direction: model.direction
                    ) { model.setThreshold($0) }
                    .frame(height: 190)

                    Label("Drag the chart to move your target", systemImage: "hand.draw")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            } else if !model.isLoadingPrice {
                Text("Not enough price history to chart yet — pick a target above.")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .background(.lorcanaDark.opacity(0.8), in: .rect(cornerRadius: 16))
        .sensoryFeedback(.selection, trigger: model.threshold)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isEditingPrice = false }
            }
        }
    }
}
