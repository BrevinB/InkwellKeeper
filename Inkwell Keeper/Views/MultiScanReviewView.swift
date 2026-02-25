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
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.minus")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No cards scanned yet")
                .font(.title3)
                .foregroundColor(.gray)
            Text("Go back and scan some cards!")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.8))
            Spacer()
        }
    }

    private var cardList: some View {
        List {
            ForEach(Array(cameraManager.scannedCards.enumerated()), id: \.element.id) { index, entry in
                ScannedCardRow(
                    entry: entry,
                    onQuantityChange: { newQuantity in
                        cameraManager.updateScannedCardQuantity(at: index, quantity: newQuantity)
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
                    if addedAll {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                        Text("Added to Collection!")
                            .font(.headline)
                    } else {
                        Image(systemName: "plus.rectangle.on.folder.fill")
                            .font(.title2)
                        Text("Add All to Collection")
                            .font(.headline)
                    }
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
            for _ in 0..<entry.quantity {
                collectionManager.addCard(entry.card)
            }
        }

        addedAll = true

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

    var body: some View {
        HStack(spacing: 12) {
            // Card image thumbnail
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
                }

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
                }
            }
        }
        .padding(.vertical, 4)
    }
}
