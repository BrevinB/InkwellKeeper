//
//  PriceAlertSaveBar.swift
//  Inkwell Keeper
//
//  The alert editor's pinned save button, with the free tier's count beside it.
//

import SwiftUI

struct PriceAlertSaveBar: View {
    let title: String
    /// Free alerts left before this one, or nil for Pro and for edits that don't add one.
    let freeAlertsRemaining: Int?
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let freeAlertsRemaining {
                Group {
                    if freeAlertsRemaining > 0 {
                        Text("\(freeAlertsRemaining) of \(PriceAlertRules.freeAlertLimit) free alerts left")
                    } else {
                        Text("You've used your free alerts. Pro unlocks unlimited.")
                    }
                }
                .font(.caption)
                .foregroundStyle(.gray)
            }

            Button(action: action) {
                Label(title, systemImage: "bell.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LorcanaButtonStyle())
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}
