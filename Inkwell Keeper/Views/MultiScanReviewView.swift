//
//  MultiScanReviewView.swift
//  Inkwell Keeper
//
//  Created by Claude on 2/25/26.
//

import SwiftUI

struct MultiScanReviewView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    var cameraManager: CameraManager
    @Binding var isPresented: Bool

    @State private var addedAll = false
    @State private var showExportPrompt = false
    @State private var showingExportView = false
    @State private var showingShareImage = false
    @State private var correctingTarget: CorrectingTarget?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if cameraManager.scannedCards.isEmpty {
                    emptyState
                } else {
                    cardList
                    if showExportPrompt {
                        exportPromptBar
                    } else {
                        bottomBar
                    }
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Scanned Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !showExportPrompt {
                        Button("Back") {
                            isPresented = false
                        }
                        .foregroundStyle(.lorcanaGold)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !cameraManager.scannedCards.isEmpty && !showExportPrompt {
                        Button("Clear All") {
                            cameraManager.clearScannedCards()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .sheet(isPresented: $showingExportView, onDismiss: dismissAfterExport) {
                ExportView(initialDateFilter: .today)
                    .environmentObject(collectionManager)
            }
            .sheet(item: $correctingTarget) { target in
                ScanCorrectionSearchView { newCard in
                    cameraManager.replaceScannedCard(at: target.index, with: newCard)
                }
            }
        }
    }

    private func dismissAfterExport() {
        cameraManager.clearScannedCards()
        isPresented = false
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.badge.minus")
                .font(.system(size: 60))
                .foregroundStyle(.lorcanaGold.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Cards Scanned Yet")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)

                Text("Go back and scan some cards!")
                    .font(.body)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardList: some View {
        List {
            ForEach(Array(cameraManager.scannedCards.enumerated()), id: \.element.id) { index, entry in
                ScannedCardRow(
                    entry: entry,
                    onQuantityChange: { newQuantity in
                        cameraManager.updateScannedCardQuantity(at: index, quantity: newQuantity)
                    },
                    onVariantChange: { newVariant in
                        cameraManager.updateScannedCardVariant(at: index, variant: newVariant)
                    },
                    onChangeCard: {
                        correctingTarget = CorrectingTarget(index: index)
                    }
                )
                .listRowBackground(Color.white.opacity(0.05))
            }
            .onDelete { indexSet in
                for index in indexSet.sorted(by: >) {
                    cameraManager.removeScannedCard(at: index)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(cameraManager.scannedCards.count) unique cards")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Spacer()
                Text("\(cameraManager.totalScannedCount) total")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }

            Button(action: addAllToCollection) {
                HStack(spacing: 8) {
                    Image(systemName: addedAll ? "checkmark.circle.fill" : "plus.rectangle.on.folder.fill")
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))
                    Text(addedAll ? "Added to Collection!" : "Add All to Collection")
                        .font(.headline)
                }
                .foregroundStyle(addedAll ? .white : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(addedAll ? Color.green : Color.lorcanaGold)
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(addedAll || cameraManager.scannedCards.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var exportPromptBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(scannedCount) cards added to your collection!")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }

            Text("Would you like to export these cards?")
                .font(.subheadline)
                .foregroundStyle(.gray)

            HStack(spacing: 12) {
                Button("Done") {
                    cameraManager.clearScannedCards()
                    isPresented = false
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.15))
                .clipShape(.rect(cornerRadius: 14))

                Button("Export", systemImage: "arrow.up.doc.fill") {
                    showingExportView = true
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.lorcanaGold)
                .clipShape(.rect(cornerRadius: 14))
            }

            Button("Share Your Haul", systemImage: "square.and.arrow.up") {
                showingShareImage = true
            }
            .font(.subheadline)
            .foregroundStyle(.lorcanaGold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingShareImage) {
            HaulShareView(entries: cameraManager.scannedCards)
        }
    }

    @State private var scannedCount = 0

    private func addAllToCollection() {
        scannedCount = cameraManager.totalScannedCount

        for entry in cameraManager.scannedCards {
            let card = entry.card.withVariant(entry.variant)
            collectionManager.addCard(card, quantity: entry.quantity)
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            addedAll = true
        }

        // Haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        Analytics.send(.scanMultiConfirmed(count: cameraManager.scannedCards.count))

        // Track multi-scan completion for review prompt
        ReviewManager.shared.recordMultiScanCompleted(cardsScanned: cameraManager.scannedCards.count)

        // Show export prompt after a brief delay
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                showExportPrompt = true
            }
        }
    }
}

struct ScannedCardRow: View {
    let entry: ScannedCardEntry
    let onQuantityChange: (Int) -> Void
    let onVariantChange: (CardVariant) -> Void
    let onChangeCard: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Card image thumbnail — tap to change/correct this card
            Button(action: onChangeCard) {
                AsyncImage(url: entry.card.bestImageUrl()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white, Color.lorcanaGold)
                        .padding(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change card: \(entry.card.name)")

            // Card info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.card.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(entry.card.setName)
                        .font(.caption2)
                        .foregroundStyle(.gray)

                    Spacer()

                    AsyncPriceWithConfidenceView(card: entry.card, style: .inline)
                }
                
                RarityBadge(rarity: entry.card.rarity)
                    .padding(2)

                // Variant picker
                HStack(spacing: 6) {
                    VariantChip(label: "Normal", isSelected: entry.variant == .normal) {
                        onVariantChange(.normal)
                    }
                    VariantChip(label: "Foil", isSelected: entry.variant == .foil) {
                        onVariantChange(.foil)
                    }
                }
            }

            Spacer()

            // Quantity stepper
            HStack(spacing: 8) {
                Button(action: {
                    onQuantityChange(entry.quantity - 1)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(entry.quantity <= 1 ? .red.opacity(0.6) : .lorcanaGold)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Decrease quantity")

                Text("\(entry.quantity)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(minWidth: 24)

                Button(action: {
                    onQuantityChange(entry.quantity + 1)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.lorcanaGold)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Increase quantity")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct VariantChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? .black : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isSelected ? Color.lorcanaGold : Color.white.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.borderless)
    }
}

/// Identifies which batch row is being corrected (drives the correction sheet).
private struct CorrectingTarget: Identifiable {
    let id = UUID()
    let index: Int
}

@MainActor
private func makePreviewCamera() -> CameraManager {
    let camera = CameraManager()
    camera.scannedCards = [
        ScannedCardEntry(
            card: LorcanaCard(
                name: "Elsa - Snow Queen",
                cost: 6,
                type: "Character",
                rarity: .legendary,
                setName: "The First Chapter",
                imageUrl: "",
                price: 12.50,
                cardNumber: 43
            ),
            quantity: 2,
            scannedAt: Date()
        ),
        ScannedCardEntry(
            card: LorcanaCard(
                name: "Moana - Of Motunui",
                cost: 4,
                type: "Character",
                rarity: .superRare,
                setName: "Rise of the Floodborn",
                imageUrl: "",
                price: 3.75,
                variant: .foil,
                cardNumber: 7
            ),
            quantity: 1,
            scannedAt: Date(),
            variant: .foil
        ),
        ScannedCardEntry(
            card: LorcanaCard(
                name: "Be Our Guest",
                cost: 3,
                type: "Action",
                rarity: .common,
                setName: "The First Chapter",
                imageUrl: "",
                price: 0.25,
                cardNumber: 22
            ),
            quantity: 3,
            scannedAt: Date()
        )
    ]
    return camera
}

#Preview("With Cards") {
    MultiScanReviewView(cameraManager: makePreviewCamera(), isPresented: .constant(true))
        .environmentObject(CollectionManager())
}

#Preview("Empty") {
    MultiScanReviewView(cameraManager: CameraManager(), isPresented: .constant(true))
        .environmentObject(CollectionManager())
}
