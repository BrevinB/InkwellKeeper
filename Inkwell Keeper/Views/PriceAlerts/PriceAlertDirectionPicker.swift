//
//  PriceAlertDirectionPicker.swift
//  Inkwell Keeper
//
//  Two big tiles for the question that matters first: waiting to buy on a
//  drop, or to sell on a rise.
//

import SwiftUI

struct PriceAlertDirectionPicker: View {
    @Binding var selection: PriceAlertDirection

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PriceAlertDirection.allCases) { direction in
                PriceAlertDirectionTile(direction: direction, isSelected: selection == direction) {
                    withAnimation(.snappy) { selection = direction }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
