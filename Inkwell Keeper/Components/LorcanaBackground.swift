//
//  LorcanaBackground.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

// MARK: - Components/LorcanaBackground.swift
import SwiftUI

struct LorcanaBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),
                    Color(red: 0.1, green: 0.05, blue: 0.15),
                    Color(red: 0.05, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            ForEach(0..<20, id: \.self) { _ in
                Circle()
                    .fill(Color.lorcanaGold.opacity(Double.random(in: 0.1...0.3)))
                    .frame(width: CGFloat.random(in: 2...6))
                    .position(
                        x: CGFloat.random(in: 0...400),
                        y: CGFloat.random(in: 0...800)
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...5))
                        .repeatForever(autoreverses: true),
                        value: UUID()
                    )
            }
        }
        .ignoresSafeArea()
    }
}
