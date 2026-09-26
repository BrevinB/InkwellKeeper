//
//  UpcomingSetBadge.swift
//  Inkwell Keeper
//
//  "Upcoming · <date>" capsule for sets that haven't released yet.
//

import SwiftUI

struct UpcomingSetBadge: View {
    let set: LorcanaSet

    var body: some View {
        Label("Upcoming · \(set.releaseDateFormatted)", systemImage: "calendar")
            .font(.caption2)
            .bold()
            .foregroundStyle(.lorcanaGold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.lorcanaGold.opacity(0.15)))
    }
}
