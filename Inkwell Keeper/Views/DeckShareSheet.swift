//
//  DeckShareSheet.swift
//  Inkwell Keeper
//
//  One place to share a deck. The hero action is the share link — it opens the app for
//  people who have it and the web deck viewer for everyone else — with the branded image
//  and the community text list as secondary options.
//

import SwiftUI

struct DeckShareSheet: View {
    let deckName: String
    let shareURL: URL
    /// Community-format text list ("4 Elsa - Snow Queen" per line) for Dreamborn/Discord.
    let deckListText: String
    /// Called after the sheet dismisses so the workspace can present the image share flow.
    var onShareImage: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var copiedLink = false
    @State private var copiedList = false
    @State private var showLinkShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.lorcanaGold)

                    Text("Share \"\(deckName)\"")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Anyone can open this link — it launches Ink Well Keeper if they have it, or shows the deck right in their browser.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                VStack(spacing: 12) {
                    Button {
                        showLinkShareSheet = true
                    } label: {
                        Label("Share Link", systemImage: "link")
                            .bold()
                            .foregroundStyle(.lorcanaDark)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.lorcanaGold)
                            .clipShape(.rect(cornerRadius: 12))
                    }

                    Button(action: copyLink) {
                        Label(copiedLink ? "Link Copied!" : "Copy Link",
                              systemImage: copiedLink ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(.lorcanaGold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.lorcanaGold, lineWidth: 2)
                            )
                    }
                    .sensoryFeedback(.success, trigger: copiedLink)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("MORE WAYS TO SHARE")
                        .font(.caption)
                        .foregroundStyle(.lorcanaGold)

                    Button(action: shareAsImage) {
                        ShareOptionRow(
                            title: "Share as Image",
                            subtitle: "A picture of the deck for social media, with a QR code",
                            systemImage: "photo"
                        )
                    }

                    Button(action: copyList) {
                        ShareOptionRow(
                            title: copiedList ? "Deck List Copied!" : "Copy Deck List",
                            subtitle: "Plain text for Dreamborn, inkdecks, or Discord",
                            systemImage: copiedList ? "checkmark" : "list.bullet"
                        )
                    }
                    .sensoryFeedback(.success, trigger: copiedList)
                }

                Spacer()
            }
            .padding()
            .background(LorcanaBackground())
            .navigationTitle("Share Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Analytics.send(.deckSharePresented)
            }
            .sheet(isPresented: $showLinkShareSheet) {
                ShareSheet(items: [shareURL]) { completed in
                    if completed { Analytics.send(.deckShareCompleted(method: "link")) }
                }
            }
        }
    }

    private func copyLink() {
        UIPasteboard.general.string = shareURL.absoluteString
        if !copiedLink { Analytics.send(.deckShareCompleted(method: "copyLink")) }
        withAnimation { copiedLink = true }
    }

    private func copyList() {
        UIPasteboard.general.string = deckListText
        if !copiedList { Analytics.send(.deckShareCompleted(method: "copyList")) }
        withAnimation { copiedList = true }
    }

    private func shareAsImage() {
        // The image flow reports itself via share.cardPresented/share.completed
        // once ShareCardPresenter takes over after dismissal.
        onShareImage()
        dismiss()
    }
}

/// A row-style secondary action in the share sheet.
struct ShareOptionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.lorcanaGold)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lorcanaDark.opacity(0.8))
        )
    }
}
