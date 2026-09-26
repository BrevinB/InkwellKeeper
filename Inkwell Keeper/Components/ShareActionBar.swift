//
//  ShareActionBar.swift
//  Inkwell Keeper
//
//  The action row shown beneath every share-card preview. Sharing a card image used to mean
//  a round trip through `UIActivityViewController` for every destination, including the two
//  people actually want most — the image in Photos, or the image on the pasteboard for Discord.
//  This view offers all three side by side and routes every one of them through the same
//  `share.actionTapped` → `share.completed` instrumentation, so the funnel is comparable
//  across share surfaces.
//

import Photos
import SwiftUI
import UIKit

struct ShareActionBar: View {
    /// Analytics discriminator for the surface presenting this bar (e.g. "cardFlex", "haul").
    let analyticsType: String
    /// The rendered card. `nil` while the preview is still preparing, which disables every action.
    let image: UIImage?
    /// On-disk PNG for the rendered card. Preferred over the raw image for both the share
    /// sheet (better for Files and AirDrop) and the Photos import.
    let fileURL: URL?
    /// Called when any action reports success, so the presenting view can stop counting a
    /// later dismissal as a drop-off.
    var onCompleted: () -> Void = {}

    @State private var showShareSheet = false
    @State private var feedback: Feedback?
    @State private var feedbackTask: Task<Void, Never>?

    /// Transient confirmation shown in place of a toast, so a completed save or copy is
    /// visibly acknowledged without dismissing the preview the user may still want to share.
    private enum Feedback: Equatable {
        case saved
        case copied
        case saveDenied
        case saveFailed

        var message: String {
            switch self {
            case .saved: "Saved to Photos"
            case .copied: "Copied to clipboard"
            case .saveDenied: "Allow photo access in Settings to save"
            case .saveFailed: "Couldn't save to Photos"
            }
        }

        var icon: String {
            switch self {
            case .saved: "checkmark.circle.fill"
            case .copied: "checkmark.circle.fill"
            case .saveDenied, .saveFailed: "exclamationmark.triangle.fill"
            }
        }

        var isError: Bool {
            switch self {
            case .saved, .copied: false
            case .saveDenied, .saveFailed: true
            }
        }
    }

    private var isReady: Bool { image != nil }

    var body: some View {
        VStack {
            HStack {
                Button("Share", systemImage: "square.and.arrow.up") {
                    Analytics.send(.shareActionTapped(type: analyticsType, action: "share"))
                    showShareSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.lorcanaGold)
                .foregroundStyle(.black)

                Button("Save", systemImage: "arrow.down.circle") {
                    Analytics.send(.shareActionTapped(type: analyticsType, action: "save"))
                    Task { await saveToPhotos() }
                }
                .buttonStyle(.bordered)
                .tint(.lorcanaGold)

                Button("Copy", systemImage: "doc.on.doc") {
                    Analytics.send(.shareActionTapped(type: analyticsType, action: "copy"))
                    copyToPasteboard()
                }
                .buttonStyle(.bordered)
                .tint(.lorcanaGold)
            }
            .disabled(!isReady)

            if let feedback {
                Label(feedback.message, systemImage: feedback.icon)
                    .font(.footnote)
                    .foregroundStyle(feedback.isError ? .red : .lorcanaGold)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: feedback == nil)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems) { completed in
                if completed {
                    Analytics.send(.shareCompleted(type: analyticsType, method: "shareSheet"))
                    onCompleted()
                }
            }
        }
        .onDisappear { feedbackTask?.cancel() }
    }

    /// Prefer sharing the on-disk PNG (better for Files/AirDrop); fall back to the raw image.
    private var shareItems: [Any] {
        if let fileURL { return [fileURL] }
        if let image { return [image] }
        return []
    }

    @MainActor
    private func copyToPasteboard() {
        guard let image else { return }
        UIPasteboard.general.image = image
        Analytics.send(.shareCompleted(type: analyticsType, method: "copy"))
        onCompleted()
        show(.copied)
    }

    /// Writes the rendered card into the user's photo library, requesting add-only access
    /// the first time. Add-only keeps the prompt narrow: the app never reads the library here.
    @MainActor
    private func saveToPhotos() async {
        guard let image else { return }

        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        guard status == .authorized || status == .limited else {
            show(.saveDenied)
            return
        }

        // Importing from the temporary PNG keeps the change block free of the UIImage and
        // preserves the exact bytes the share sheet would have handed out.
        let fileURL = fileURL
        let pngData = fileURL == nil ? image.pngData() : nil
        do {
            try await PHPhotoLibrary.shared().performChanges {
                if let fileURL {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
                } else if let pngData {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: pngData, options: nil)
                }
            }
            Analytics.send(.shareCompleted(type: analyticsType, method: "save"))
            onCompleted()
            show(.saved)
        } catch {
            show(.saveFailed)
        }
    }

    @MainActor
    private func show(_ value: Feedback) {
        feedback = value
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            feedback = nil
        }
    }
}
