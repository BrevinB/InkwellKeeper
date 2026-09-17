//
//  PurchasePriceRow.swift
//  Inkwell Keeper
//
//  Records what a copy cost, which is what turns the collection's market value
//  into an actual gain or loss.
//

import SwiftUI
import SwiftData

struct PurchasePriceRow: View {
    let collected: CollectedCard

    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text("Paid:")
                .font(.subheadline)
                .foregroundStyle(.gray)

            Spacer()

            if isEditing {
                TextField("0.00", text: $draft)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($isFocused)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 110)
                    .onSubmit(commit)

                Button("Save", action: commit)
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.lorcanaGold)
            } else {
                Button(action: beginEditing) {
                    if let paid = collected.purchasePrice {
                        Text(
                            paid,
                            format: .currency(code: PricingService.preferredCurrency)
                                .precision(.fractionLength(2))
                        )
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    } else {
                        Text("Add")
                            .font(.subheadline)
                            .foregroundStyle(Color.lorcanaGold)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Purchase price per copy")
    }

    private func beginEditing() {
        draft = collected.purchasePrice.map { String(format: "%.2f", $0) } ?? ""
        isEditing = true
        isFocused = true
    }

    private func commit() {
        let cleaned = draft.trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty {
            collected.purchasePrice = nil
        } else if let value = Double(cleaned.replacing(",", with: ".")), value >= 0 {
            collected.purchasePrice = value
        }
        try? modelContext.save()
        isEditing = false
        isFocused = false
    }
}
