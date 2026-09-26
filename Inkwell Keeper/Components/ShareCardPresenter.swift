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
    /// Canvas height forwarded to the chrome; `nil` renders a flexible-height card that
    /// grows with its content instead of clipping it.
    var canvasHeight: CGFloat? = ShareCardLayout.size.height
    /// Card artwork to preload before rendering, keyed by an id the template understands.
    var preloadURLs: [String: URL] = [:]
    /// Builds the template's inner content given the preloaded images.
    @ViewBuilder let card: ([String: UIImage]) -> Card

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?
    @State private var shareURL: URL?
    @State private var isPreparing = true
    /// Set once any action reports success, so dismissing afterwards isn't counted as a drop-off.
    @State private var didComplete = false

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
        .onDisappear {
            guard !didComplete else { return }
            Analytics.send(.shareDismissed(type: analyticsType, stage: dismissalStage))
        }
    }

    @ViewBuilder
    private func preview(_ image: UIImage) -> some View {
        VStack(spacing: 24) {
            // Scrollable so flexible-height cards (long rulings) stay readable
            // instead of scaling down to fit.
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 20))
                    .shadow(radius: 12, y: 6)
                    .padding(.horizontal, 32)
            }
            .scrollIndicators(.hidden)

            ShareActionBar(analyticsType: analyticsType, image: image, fileURL: shareURL) {
                didComplete = true
            }
        }
        .padding(.vertical, 24)
    }

    /// Where the user was when they walked away, which is what splits a slow render from a
    /// card that rendered fine and simply didn't earn a share.
    private var dismissalStage: String {
        if isPreparing { return "preparing" }
        return rendered == nil ? "failed" : "preview"
    }

    @MainActor
    private func prepare() async {
        Analytics.send(.shareCardPresented(type: analyticsType))
        let start = ContinuousClock.now
        let images = preloadURLs.isEmpty ? [:] : await ShareImageRenderer.preload(preloadURLs)
        let composed = ShareCardChrome(qrPayload: qrPayload, tagline: tagline, height: canvasHeight) {
            card(images)
        }
        let image = ShareImageRenderer.render(composed)
        rendered = image
        if let image {
            shareURL = ShareImageRenderer.temporaryFileURL(for: image, name: fileName)
            Analytics.send(.shareRendered(type: analyticsType, milliseconds: start.millisecondsElapsed))
        } else {
            Analytics.send(.shareRenderFailed(type: analyticsType))
        }
        isPreparing = false
    }
}
