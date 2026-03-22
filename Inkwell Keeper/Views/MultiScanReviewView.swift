//
//  MultiScanReviewView.swift
//  Inkwell Keeper
//
//  Created by Claude on 2/25/26.
//

import SwiftUI

struct MultiScanReviewView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @ObservedObject var cameraManager: CameraManager
    @Binding var isPresented: Bool

    @State private var addedAll = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if cameraManager.scannedCards.isEmpty {
                    emptyState
                } else {
                    cardList
                    bottomBar
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Scanned Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        isPresented = false
                    }
                    .foregroundColor(.lorcanaGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !cameraManager.scannedCards.isEmpty {
                        Button("Clear All") {
                            cameraManager.clearScannedCards()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.badge.minus")
                .font(.system(size: 60))
                .foregroundColor(.lorcanaGold.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Cards Scanned Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Go back and scan some cards!")
                    .font(.body)
                    .foregroundColor(.gray)
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
                    .foregroundColor(.gray)
                Spacer()
                Text("\(cameraManager.totalScannedCount) total")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Button(action: addAllToCollection) {
                HStack(spacing: 8) {
                    Image(systemName: addedAll ? "checkmark.circle.fill" : "plus.rectangle.on.folder.fill")
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))
                    Text(addedAll ? "Added to Collection!" : "Add All to Collection")
                        .font(.headline)
                }
                .foregroundColor(addedAll ? .white : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(addedAll ? Color.green : Color.lorcanaGold)
                .cornerRadius(14)
            }
            .disabled(addedAll || cameraManager.scannedCards.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func addAllToCollection() {
        for entry in cameraManager.scannedCards {
            let card = entry.card.withVariant(entry.variant)
            let imageAttachments: [Data]? = entry.capturedImage.map { [$0] }
            collectionManager.addCard(card, quantity: entry.quantity, imageAttachments: imageAttachments)
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            addedAll = true
        }

        // Haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        // Dismiss after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            cameraManager.clearScannedCards()
            isPresented = false
        }
    }
}

struct ScannedCardRow: View {
    let entry: ScannedCardEntry
    let onQuantityChange: (Int) -> Void
    let onVariantChange: (CardVariant) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Card image thumbnail
            ZStack(alignment: .bottomTrailing) {
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

                if entry.capturedImage != nil {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Circle().fill(Color.lorcanaGold))
                        .offset(x: 2, y: 2)
                }
            }

            // Card info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.card.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(entry.card.setName)
                        .font(.caption2)
                        .foregroundColor(.gray)

                    RarityBadge(rarity: entry.card.rarity)

                    Spacer()

                    AsyncPriceWithConfidenceView(card: entry.card, style: .inline)
                }

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
                        .foregroundColor(entry.quantity <= 1 ? .red.opacity(0.6) : .lorcanaGold)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)

                Text("\(entry.quantity)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(minWidth: 24)

                Button(action: {
                    onQuantityChange(entry.quantity + 1)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.lorcanaGold)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
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
                .foregroundColor(isSelected ? .black : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isSelected ? Color.lorcanaGold : Color.white.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(.borderless)
    }
}
