//
//  CardFlexShareView.swift
//  Inkwell Keeper
//
//  "Card flex" sharing: a hero presentation of a single card. When the user attached their own
//  photo of the card, they can choose between that photo and the catalog art. Contains the data
//  snapshot, the presentation-only template, and a small dedicated presenter that owns the
//  My-photo/Catalog toggle (the generic ShareCardPresenter renders only once).
//

import SwiftUI
import UIKit

/// Immutable snapshot of the card a flex shares, built at the call site from a `CollectedCard`.
struct CardFlexShareData {
    let id: String
    let name: String
    let setName: String
    let rarity: CardRarity
    let variant: CardVariant
    /// How many copies of this card the user owns, surfaced as a "×N" badge.
    let ownedQuantity: Int
    /// The catalog/local artwork URL (resolved via `bestImageUrl()`), preloaded by the presenter.
    let catalogImageURL: URL?
    /// The user's own attached photo, if any (already decoded — lives in memory).
    let userPhoto: UIImage?

    var hasUserPhoto: Bool { userPhoto != nil }
}

// MARK: - Template

struct CardFlexShareCardView: View {
    let data: CardFlexShareData
    let image: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.06))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                        .aspectRatio(0.72, contentMode: .fit)
                }
            }
            .frame(maxHeight: 230)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                if data.ownedQuantity > 1 {
                    Text("×\(data.ownedQuantity)")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(8)
                        .shadow(radius: 4)
                }
            }
            .shadow(color: data.rarity.color.opacity(0.5), radius: 14)

            VStack(spacing: 6) {
                Text(data.name)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(data.rarity.displayName, systemImage: "circle.fill")
                        .labelStyle(RarityGemLabelStyle(color: data.rarity.color))
                    if data.variant != .normal {
                        Text(data.variant.displayName)
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.lorcanaGold)
                    }
                }

                Text(data.setName)
                    .font(.caption)
                    .foregroundStyle(.lorcanaGold)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Tiny rarity "gem" label: a colored dot followed by the rarity name.
private struct RarityGemLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .font(.system(size: 8))
                .foregroundStyle(color)
            configuration.title
                .font(.caption)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Presenter

struct CardFlexShareView: View {
    let data: CardFlexShareData

    @Environment(\.dismiss) private var dismiss
    @State private var useUserPhoto: Bool
    @State private var catalogImage: UIImage?
    @State private var rendered: UIImage?
    @State private var shareURL: URL?
    @State private var isPreparing = true
    @State private var showShareSheet = false

    init(data: CardFlexShareData) {
        self.data = data
        _useUserPhoto = State(initialValue: data.userPhoto != nil)
    }

    private var qrPayload: String {
        AppLinks.cardQRPayload(id: data.id)
    }

    private var activeImage: UIImage? {
        useUserPhoto ? data.userPhoto : catalogImage
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                VStack(spacing: 20) {
                    if let rendered {
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 20))
                            .shadow(radius: 12, y: 6)
                            .padding(.horizontal, 32)
                    } else if isPreparing {
                        ProgressView("Preparing your card…")
                            .tint(.lorcanaGold)
                    }

                    if data.hasUserPhoto {
                        Picker("Image", selection: $useUserPhoto) {
                            Text("My Photo").tag(true)
                            Text("Catalog Art").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 32)
                    }

                    Button("Share", systemImage: "square.and.arrow.up") {
                        showShareSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.lorcanaGold)
                    .foregroundStyle(.black)
                    .disabled(rendered == nil)
                }
                .padding(.vertical, 24)
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
        .onChange(of: useUserPhoto) { _, _ in renderCard() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems) { completed in
                if completed { Analytics.send(.shareCompleted(type: "cardFlex")) }
            }
        }
    }

    private var shareItems: [Any] {
        if let shareURL { return [shareURL] }
        if let rendered { return [rendered] }
        return []
    }

    @MainActor
    private func prepare() async {
        Analytics.send(.shareCardPresented(type: "cardFlex"))
        catalogImage = await ShareImageRenderer.loadImage(from: data.catalogImageURL)
        // If there's no user photo, fall back to catalog art as the active image.
        if data.userPhoto == nil { useUserPhoto = false }
        renderCard()
        isPreparing = false
    }

    @MainActor
    private func renderCard() {
        let composed = ShareCardChrome(qrPayload: qrPayload) {
            CardFlexShareCardView(data: data, image: activeImage)
        }
        guard let image = ShareImageRenderer.render(composed) else { return }
        rendered = image
        shareURL = ShareImageRenderer.temporaryFileURL(for: image, name: "InkwellKeeper-\(data.name)")
    }
}

// MARK: - Previews

private extension CardFlexShareData {
    static let preview = CardFlexShareData(
        id: "ARI-001",
        name: "Elsa - Spirit of Winter",
        setName: "Archazia's Island",
        rarity: .legendary,
        variant: .foil,
        ownedQuantity: 2,
        catalogImageURL: nil,
        userPhoto: nil
    )
}

#Preview("Card Template") {
    CardFlexShareCardView(data: .preview, image: nil)
        .frame(width: 300, height: 400)
        .background(.black)
}

#Preview("Share View") {
    CardFlexShareView(data: .preview)
}
