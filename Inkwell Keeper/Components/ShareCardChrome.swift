//
//  ShareCardChrome.swift
//  Inkwell Keeper
//
//  The shared branded frame that wraps every share-card template so they read as a family
//  and always carry the wordmark + a QR code back to the app. Designed for off-screen
//  rendering at a fixed 4:5 canvas (great for Instagram, Discord, and message previews).
//

import SwiftUI
import UIKit

/// Canonical layout constants for share cards.
enum ShareCardLayout {
    /// Point size of the rendered canvas. At 3x this yields a 1080×1350px image.
    static let size = CGSize(width: 360, height: 450)
    static let cornerRadius: CGFloat = 28
    static let contentPadding: CGFloat = 20
}

/// Wraps a template's `content` in the brand background, gold edge, and promotional footer.
struct ShareCardChrome<Content: View>: View {
    /// String encoded into the footer QR (a deep link, or the App Store URL as a fallback).
    let qrPayload: String
    /// Short call-to-action shown next to the wordmark.
    var tagline: String = "Track your Lorcana collection"
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 16) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            ShareCardFooter(qrPayload: qrPayload, tagline: tagline)
        }
        .padding(ShareCardLayout.contentPadding)
        .frame(width: ShareCardLayout.size.width, height: ShareCardLayout.size.height)
        .background {
            // The real app background (gradient + gold sparkles), captured as a still frame
            // by ImageRenderer. Clipped to the card's rounded rect below.
            LorcanaBackground()
        }
        .clipShape(.rect(cornerRadius: ShareCardLayout.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ShareCardLayout.cornerRadius)
                .strokeBorder(.lorcanaGold.opacity(0.55), lineWidth: 1.5)
        }
    }
}

/// The promotional footer: wordmark + tagline on the left, scannable QR on the right.
struct ShareCardFooter: View {
    let qrPayload: String
    let tagline: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Ink Well Keeper", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.lorcanaGold)
                    .labelStyle(.titleAndIcon)
                Text(tagline)
                    .font(.caption2)
                    .foregroundStyle(.lorcanaGold)
            }

            Spacer(minLength: 0)

            if let qrImage = QRCodeGenerator.image(from: qrPayload) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .padding(4)
                    .background(.white.opacity(0.06), in: .rect(cornerRadius: 8))
            }
        }
        .padding(.top, 4)
    }
}

#Preview("Share Card Chrome") {
    let mockData = CardFlexShareData(
        id: "preview-001",
        name: "Elsa - Spirit of Winter",
        setName: "The First Chapter",
        rarity: .legendary,
        variant: .foil,
        ownedQuantity: 2,
        catalogImageURL: nil,
        userPhoto: nil
    )
    ShareCardChrome(qrPayload: "https://apps.apple.com/app/inkwell-keeper") {
        CardFlexShareCardView(data: mockData, image: nil)
    }
}

#Preview("Share Card Footer") {
    ShareCardFooter(
        qrPayload: "https://apps.apple.com/app/inkwell-keeper",
        tagline: "Track your Lorcana collection"
    )
    .padding()
    .background(Color(red: 0.10, green: 0.09, blue: 0.16))
}
