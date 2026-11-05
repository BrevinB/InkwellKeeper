//
//  PriceAlertBellTip.swift
//  Inkwell Keeper
//
//  Points at the price-alert bell on a card screen the first time one opens.
//  Shown once, and retired for good as soon as the user sets an alert.
//

import SwiftUI
import TipKit

struct PriceAlertBellTip: Tip {
    var title: Text {
        Text("Watch This Card's Price")
    }

    var message: Text? {
        Text("Tap the bell and we'll let you know when it drops to a price you'd buy at, or rises to one you'd sell at.")
    }

    var image: Image? {
        Image(systemName: "bell.badge")
    }

    var options: [any TipOption] {
        MaxDisplayCount(1)
    }
}
