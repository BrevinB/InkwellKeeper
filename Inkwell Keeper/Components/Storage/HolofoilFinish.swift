//
//  HolofoilFinish.swift
//  Inkwell Keeper
//
//  Slowly turning rainbow for the Holofoil cover finish.
//

import SwiftUI

struct HolofoilFinish: View {
    let animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animated)) { timeline in
            let degrees = animated ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12) * 30 : 45
            AngularGradient(
                colors: [.pink, .yellow, .mint, .cyan, .purple, .pink],
                center: .center,
                angle: .degrees(degrees)
            )
            .opacity(0.24)
            .blendMode(.overlay)
        }
    }
}
