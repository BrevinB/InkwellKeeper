//
//  PriceAlertCardHeader.swift
//  Inkwell Keeper
//
//  The top of the alert editor: which printing is being watched and what it
//  sells for today.
//

import SwiftUI

struct PriceAlertCardHeader: View {
    let model: PriceAlertEditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                AsyncImage(url: model.card.bestImageUrl()) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 64, height: 90)
                .clipShape(.rect(cornerRadius: 8))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.card.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(model.card.setName)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text("Market price")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    PriceAlertMarketPrice(price: model.currentPrice, isLoading: model.isLoadingPrice)
                }

                Spacer(minLength: 0)
            }

            if !model.variantChoices.isEmpty {
                Picker(
                    "Printing",
                    selection: Binding(
                        get: { model.card.variant },
                        set: { variant in Task { await model.selectVariant(variant) } }
                    )
                ) {
                    ForEach(model.variantChoices, id: \.self) { variant in
                        Text(variant.displayName).tag(variant)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(.lorcanaDark.opacity(0.8), in: .rect(cornerRadius: 16))
    }
}
