//
//  PriceAlertNudgeButton.swift
//  Inkwell Keeper
//
//  Steps the alert target one price-sized step up or down. Holding it repeats.
//

import SwiftUI

struct PriceAlertNudgeButton: View {
    let up: Bool
    let action: () -> Void

    var body: some View {
        Button(up ? "Raise target" : "Lower target", systemImage: up ? "plus" : "minus", action: action)
            .labelStyle(.iconOnly)
            .font(.title3.bold())
            .foregroundStyle(.lorcanaGold)
            .frame(width: 44, height: 44)
            .background(.lorcanaGold.opacity(0.12), in: .circle)
            .buttonRepeatBehavior(.enabled)
    }
}
