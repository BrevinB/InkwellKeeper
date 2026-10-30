//
//  ChartRangePicker.swift
//  Inkwell Keeper
//
//  Segmented 1W / 1M / 3M / All control above a value-history chart.
//

import SwiftUI

struct ChartRangePicker: View {
    let ranges: [ChartRange]
    @Binding var selection: ChartRange

    var body: some View {
        Picker("Time range", selection: $selection) {
            ForEach(ranges) { range in
                Text(range.rawValue)
                    .accessibilityLabel(range.accessibilityName)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
