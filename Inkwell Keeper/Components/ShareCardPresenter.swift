//
//  ShareCardPresenter.swift
//  Inkwell Keeper
//
//  Reusable sheet that turns any share-card template into a shareable image: it preloads the
//  template's card artwork, renders it off-screen with `ShareImageRenderer`, shows a preview,
//  and hands the result to the system share sheet. Every share entry point routes through here
//  so the preload → render → share wiring exists in exactly one place.
//

import SwiftUI
import UIKit

struct ShareCardPresenter<Card: View>: View {
    /// Analytics discriminator for this share surface (e.g. "deck", "milestone").
    let analyticsType: String
    /// Payload encoded into the footer QR code (deep link or App Store URL).
    let qrPayload: String
    /// Footer call-to-action.
    var tagline: String = "Track your Lorcana collection"
    /// File-name stem for the exported PNG.
    var fileName: String = "InkwellKeeper-Share"
    /// Card artwork to preload before rendering, keyed by an id the template understands.
    var preloadURLs: [String: URL] = [:]
    /// Builds the template's inner content given the preloaded images.
    @ViewBuilder let card: ([String: UIImage]) -> Card

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?
    @State private var shareURL: URL?
    @State private var isPreparing = true
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                if let rendered {
                    preview(rendered)
                } else if isPreparing {
                    ProgressView("Preparing your card…")
                        .tint(.lorcanaGold)
                } else {
                    ContentUnavailableView(
                        "Couldn't create image",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Something went wrong rendering your share card.")
                    )
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await prepare() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems) { completed in
                if completed { Analytics.send(.shareCompleted(type: analyticsType)) }
            }
        }
    }

    /// Prefer sharing the on-disk PNG (better for Files/AirDrop); fall back to the raw image.
    private var shareItems: [Any] {
        if let shareURL { return [shareURL] }
        if let rendered { return [rendered] }
        return []
    }

    @ViewBuilder
    private func preview(_ image: UIImage) -> some View {
        VStack(spacing: 24) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 20))
                .shadow(radius: 12, y: 6)
                .padding(.horizontal, 32)

            Button("Share", systemImage: "square.and.arrow.up") {
                showShareSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.lorcanaGold)
            .foregroundStyle(.black)
        }
        .padding(.vertical, 24)
    }

    @MainActor
    private func prepare() async {
        Analytics.send(.shareCardPresented(type: analyticsType))
        let images = preloadURLs.isEmpty ? [:] : await ShareImageRenderer.preload(preloadURLs)
        let composed = ShareCardChrome(qrPayload: qrPayload, tagline: tagline) {
            card(images)
        }
        let image = ShareImageRenderer.render(composed)
        rendered = image
        if let image {
            shareURL = ShareImageRenderer.temporaryFileURL(for: image, name: fileName)
        }
        isPreparing = false
    }
}
