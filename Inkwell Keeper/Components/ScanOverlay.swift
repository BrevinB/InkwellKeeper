//
//  ScanOverlay.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct ScanOverlay: View {
    private let frameWidth: CGFloat = 250
    private let frameHeight: CGFloat = 350
    private let cornerRadius: CGFloat = 20
    private let armLength: CGFloat = 40
    private let lineWidth: CGFloat = 3

    var body: some View {
        VStack(spacing: 16) {
            CornerBrackets(
                cornerRadius: cornerRadius,
                armLength: armLength,
                lineWidth: lineWidth
            )
            .stroke(Color.lorcanaGold, lineWidth: lineWidth)
            .frame(width: frameWidth, height: frameHeight)

            Text("Position card within frame")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                )
        }
    }
}

// MARK: - Corner Brackets Shape

private struct CornerBrackets: Shape {
    let cornerRadius: CGFloat
    let armLength: CGFloat
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Top-left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius + armLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius + armLength, y: rect.minY))

        // Top-right corner
        path.move(to: CGPoint(x: rect.maxX - cornerRadius - armLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius + armLength))

        // Bottom-right corner
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius - armLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius - armLength, y: rect.maxY))

        // Bottom-left corner
        path.move(to: CGPoint(x: rect.minX + cornerRadius + armLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius - armLength))

        return path
    }
}
