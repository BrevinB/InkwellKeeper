//
//  CardBackView.swift
//  Inkwell Keeper
//
//  Face-down card used during the pack reveal animation.
//

import SwiftUI

struct CardBackView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.14, blue: 0.30),
                            Color(red: 0.18, green: 0.11, blue: 0.32),
                            Color(red: 0.07, green: 0.10, blue: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.lorcanaGold.opacity(0.8), lineWidth: 2)

            Image(systemName: "drop.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.lorcanaGold, .white, Color.lorcanaGold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.lorcanaGold.opacity(0.6), radius: 10)
        }
        .staticFoilEffect()
        .clipShape(.rect(cornerRadius: 12))
    }
}

#Preview {
    CardBackView()
        .aspectRatio(0.717, contentMode: .fit)
        .frame(width: 220)
        .padding()
        .background(.black)
}
