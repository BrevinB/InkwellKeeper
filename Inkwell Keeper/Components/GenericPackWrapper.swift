//
//  GenericPackWrapper.swift
//  Inkwell Keeper
//
//  A generic, Inkwell-themed foil booster pack drawn entirely in SwiftUI,
//  with crimped (heat-sealed) ends. `tearProgress` rips the top strip away
//  along a jagged tear line.
//

import SwiftUI

struct GenericPackWrapper: View {
    var setName: String
    /// 0 = sealed, 1 = top strip fully ripped off.
    var tearProgress: Double = 0

    private let tearFraction: CGFloat = 0.20
    private let crimpDepth: CGFloat = 13

    var body: some View {
        ZStack {
            // Main body — stays in "hand", leans slightly as the strip releases.
            clippedPiece(.body)
                .rotationEffect(.degrees(tearProgress * 2.5), anchor: .bottom)

            // Top strip — tears up and off along the jagged seam.
            clippedPiece(.top)
                .rotationEffect(.degrees(tearProgress * 22), anchor: .bottomLeading)
                .offset(x: tearProgress * 34, y: -tearProgress * 270)
                .opacity(1 - tearProgress)
        }
        .compositingGroup()
        .shadow(color: Color.lorcanaGold.opacity(0.35), radius: 24)
    }

    private func clippedPiece(_ part: PackPiece.Part) -> some View {
        let shape = PackPiece(part: part, tearFraction: tearFraction, crimpDepth: crimpDepth)
        return packArt
            .clipShape(shape)
            .overlay(shape.stroke(Color.black.opacity(0.35), lineWidth: 1.5))
    }

    // MARK: - Pack artwork

    private var packArt: some View {
        ZStack {
            Rectangle().fill(bodyGradient)
            crimpBands
            contentStack
        }
        .staticFoilEffect()
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.12, blue: 0.26),
                Color(red: 0.16, green: 0.10, blue: 0.30),
                Color(red: 0.05, green: 0.09, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Lighter foil bands at the crimped ends, with vertical crimp ridges.
    private var crimpBands: some View {
        VStack {
            crimpBand
            Spacer()
            crimpBand
        }
    }

    private var crimpBand: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.lorcanaGold.opacity(0.55), Color.lorcanaGold.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            HStack(spacing: 4) {
                ForEach(0..<32, id: \.self) { _ in
                    Rectangle()
                        .fill(.black.opacity(0.22))
                        .frame(width: 1.5)
                }
            }
        }
        .frame(height: crimpDepth + 18)
    }

    private var contentStack: some View {
        VStack(spacing: 12) {
            Text("INKWELL KEEPER")
                .font(.caption.bold())
                .tracking(2)
                .foregroundStyle(Color.lorcanaGold)

            Image(systemName: "drop.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.lorcanaGold, .white, Color.lorcanaGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.lorcanaGold.opacity(0.6), radius: 12)

            Text("BOOSTER PACK")
                .font(.title3.bold())
                .tracking(3)
                .foregroundStyle(.white)

            Text(setName)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding()
        // Nudged into the body so nothing rides on the strip that tears off.
        .offset(y: 24)
    }
}

/// One half of the pack pouch — a crimped end joined to a jagged tear line.
/// Both parts share the same tear line so they tile perfectly when sealed.
struct PackPiece: Shape {
    enum Part { case top, body }

    var part: Part
    var tearFraction: CGFloat
    var crimpDepth: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let tearY = h * tearFraction
        var path = Path()

        // Deterministic jagged tear line, left -> right, pinned at the sides.
        func tearLine() -> [CGPoint] {
            let segment: CGFloat = 14
            let count = max(6, Int(w / segment))
            return (0...count).map { i in
                let x = w * CGFloat(i) / CGFloat(count)
                var y = tearY
                if i != 0 && i != count {
                    let raw = sin(Double(i) * 12.9898 + 4.0) * 43758.5453
                    let frac = raw - raw.rounded(.down)
                    y += CGFloat(frac - 0.5) * 20
                }
                return CGPoint(x: x, y: y)
            }
        }

        // Crimp (heat-seal) zigzag along a horizontal edge.
        func crimp(edgeY: CGFloat, depthSign: CGFloat) -> [CGPoint] {
            let toothWidth: CGFloat = 11
            var count = max(8, Int(w / toothWidth))
            if count % 2 != 0 { count += 1 }   // even -> both ends are peaks
            return (0...count).map { i in
                let x = w * CGFloat(i) / CGFloat(count)
                let isValley = i % 2 != 0
                let y = edgeY + (isValley ? crimpDepth * depthSign : 0)
                return CGPoint(x: x, y: y)
            }
        }

        let tear = tearLine()

        switch part {
        case .top:
            let topEdge = crimp(edgeY: 0, depthSign: 1)
            path.move(to: topEdge[0])
            for point in topEdge.dropFirst() { path.addLine(to: point) }
            for point in tear.reversed() { path.addLine(to: point) }
            path.closeSubpath()

        case .body:
            let bottomEdge = crimp(edgeY: h, depthSign: -1)
            path.move(to: tear[0])
            for point in tear.dropFirst() { path.addLine(to: point) }
            for point in bottomEdge.reversed() { path.addLine(to: point) }
            path.closeSubpath()
        }

        return path
    }
}

#Preview {
    HStack(spacing: 20) {
        GenericPackWrapper(setName: "The First Chapter")
            .frame(width: 200, height: 330)
        GenericPackWrapper(setName: "The First Chapter", tearProgress: 0.55)
            .frame(width: 200, height: 330)
    }
    .padding()
    .background(.black)
}
