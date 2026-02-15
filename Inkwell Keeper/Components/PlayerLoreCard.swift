//
//  PlayerLoreCard.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 2/14/26.
//

import SwiftUI

struct PlayerLoreCard: View {
    @Binding var player: PlayerLore
    var onLoreChange: (Int, Int) -> Void // (oldValue, newValue)

    @State private var isEditingName = false
    @State private var showCustomValuePicker = false
    @State private var customValue: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var winGlow = false
    @State private var hapticTrigger = 0
    @State private var winHapticTrigger = 0

    private let winThreshold = 20
    private let dragThreshold: CGFloat = 40

    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(player.inkColor.color.opacity(hasWon ? 1.0 : 0.5), lineWidth: hasWon ? 3 : 2)
                )
                .shadow(color: hasWon ? Color.lorcanaGold.opacity(winGlow ? 0.8 : 0.3) : .clear, radius: hasWon ? 20 : 0)

            VStack(spacing: 8) {
                playerHeader

                Spacer(minLength: 0)

                loreCounter

                Spacer(minLength: 0)

                inkColorSelector
            }
            .padding(12)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
        .sensoryFeedback(.impact(weight: .heavy), trigger: winHapticTrigger)
        .onChange(of: player.lore) { _, newValue in
            if newValue >= winThreshold {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    winGlow = true
                }
                winHapticTrigger += 1
            } else {
                winGlow = false
            }
        }
        .sheet(isPresented: $showCustomValuePicker) {
            customValueSheet
        }
    }

    // MARK: - Subviews

    private var playerHeader: some View {
        Group {
            if isEditingName {
                TextField("Name", text: $player.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .onSubmit { isEditingName = false }
            } else {
                Text(player.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9))
                    .onTapGesture { isEditingName = true }
            }
        }
    }

    private var loreCounter: some View {
        HStack(spacing: 16) {
            // Minus button
            Button {
                adjustLore(by: -1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(player.inkColor.color)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    customValue = player.lore
                    showCustomValuePicker = true
                }
            )

            // Lore number
            Text("\(player.lore)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(hasWon ? .lorcanaGold : .white)
                .contentTransition(.numericText())
                .animation(.snappy, value: player.lore)

            // Plus button
            Button {
                adjustLore(by: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(player.inkColor.color)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    customValue = player.lore
                    showCustomValuePicker = true
                }
            )
        }
    }

    private var inkColorSelector: some View {
        HStack(spacing: 6) {
            ForEach(InkColor.allCases, id: \.self) { ink in
                let isSelected = player.inkColor == ink
                Circle()
                    .fill(ink.color)
                    .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            player.inkColor = ink
                        }
                    }
            }
        }
    }

    private var customValueSheet: some View {
        CustomValuePickerSheet(
            customValue: $customValue,
            inkColor: player.inkColor,
            onApply: {
                let old = player.lore
                player.lore = customValue
                onLoreChange(old, customValue)
                showCustomValuePicker = false
            },
            onCancel: {
                showCustomValuePicker = false
            }
        )
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                let verticalDrag = value.translation.height
                if verticalDrag < -dragThreshold {
                    adjustLore(by: 1)
                } else if verticalDrag > dragThreshold {
                    adjustLore(by: -1)
                }
                dragOffset = 0
            }
    }

    // MARK: - Helpers

    private var hasWon: Bool {
        player.lore >= winThreshold
    }

    private func adjustLore(by amount: Int) {
        let old = player.lore
        let newValue = max(0, min(20, old + amount))
        guard newValue != old else { return }
        withAnimation(.snappy) {
            player.lore = newValue
        }
        onLoreChange(old, newValue)
        hapticTrigger += 1
    }
}

// MARK: - Custom Value Picker (extracted to help type-checker)

private struct CustomValuePickerSheet: View {
    @Binding var customValue: Int
    let inkColor: InkColor
    let onApply: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Set Lore Value")
                    .font(.headline)
                    .foregroundColor(.white)

                Stepper(value: $customValue, in: 0...20) {
                    Text("\(customValue)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.lorcanaGold)
                        .frame(maxWidth: .infinity)
                }
                .tint(inkColor.color)

                Button("Apply", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .tint(inkColor.color)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.lorcanaDark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.lorcanaGold)
                }
            }
        }
        .presentationDetents([.height(280)])
        .preferredColorScheme(.dark)
    }
}
