//
//  PackOpeningView.swift
//  Inkwell Keeper
//
//  Entry point for the "rip open a pack" feature — a purely cosmetic
//  pack simulator that does not affect the user's collection.
//

import SwiftUI

struct PackOpeningView: View {
    @State private var simulator = PackSimulator()

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                content
                    .transition(.opacity)
            }
            .navigationTitle("Open Packs")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch simulator.phase {
        case .choosingSet:
            PackSetPickerView(simulator: simulator)
        case .sealed:
            SealedPackView(simulator: simulator)
        case .revealing:
            PackRevealView(simulator: simulator)
        case .summary:
            PackSummaryView(simulator: simulator)
        }
    }
}

#Preview {
    PackOpeningView()
        .preferredColorScheme(.dark)
}
