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
    @State private var plusPressed = false
    @State private var minusPressed = false

    private let winThreshold = 20
    private let dragThreshold: CGFloat = 40

    var body: some View {
        ZStack {
            // Card background with ink-tinted gradient
            cardBackground

            VStack(spacing: 0) {
                playerHeader
                    .padding(.top, 10)

                Spacer(minLength: 0)

                // Lore ring + number
                loreRing

                Spacer(minLength: 0)

                // +/- controls
                loreControls
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 12)
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

    // MARK: - Card Background

    private var cardBackground: some View {
        ZStack {
            // Base dark fill with ink color gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            player.inkColor.color.opacity(0.25),
                            Color.lorcanaDark.opacity(0.95),
                            Color.lorcanaDark.opacity(0.9),
                            player.inkColor.color.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Border
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            player.inkColor.color.opacity(hasWon ? 1.0 : 0.6),
                            player.inkColor.color.opacity(hasWon ? 0.8 : 0.2),
                            player.inkColor.color.opacity(hasWon ? 1.0 : 0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: hasWon ? 3 : 1.5
                )

            // Win glow
            if hasWon {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.lorcanaGold.opacity(winGlow ? 0.6 : 0.1), lineWidth: 4)
                    .blur(radius: 8)
            }
        }
        .shadow(color: hasWon ? Color.lorcanaGold.opacity(winGlow ? 0.5 : 0.15) : player.inkColor.color.opacity(0.15), radius: hasWon ? 16 : 6)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .onSubmit { isEditingName = false }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundColor(player.inkColor.color.opacity(0.8))

                    Text(player.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06), in: Capsule())
                .onTapGesture { isEditingName = true }
            }
        }
    }

    // MARK: - Lore Ring

    private var loreRing: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.85
            ZStack {
                // Track ring
                Circle()
                    .stroke(player.inkColor.color.opacity(0.15), lineWidth: 6)

                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(player.lore) / CGFloat(winThreshold))
                    .stroke(
                        AngularGradient(
                            colors: [
                                player.inkColor.color.opacity(0.4),
                                player.inkColor.color,
                                hasWon ? Color.lorcanaGold : player.inkColor.color
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: player.lore)

                // Lore number
                Text("\(player.lore)")
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundColor(hasWon ? .lorcanaGold : .white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: player.lore)

                // Win label
                if hasWon {
                    Text("VICTORY")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.lorcanaGold)
                        .tracking(2)
                        .offset(y: size * 0.28)
                }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .onTapGesture {
            customValue = player.lore
            showCustomValuePicker = true
        }
    }

    // MARK: - Lore Controls

    private var loreControls: some View {
        HStack(spacing: 0) {
            // Minus button
            Button {
                minusPressed = true
                adjustLore(by: -1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { minusPressed = false }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(player.inkColor.color.opacity(minusPressed ? 0.4 : 0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(player.inkColor.color.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: "minus")
                        .font(.title2.weight(.bold))
                        .foregroundColor(player.inkColor.color)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    customValue = player.lore
                    showCustomValuePicker = true
                }
            )

            Spacer()
                .frame(width: 12)

            // Plus button
            Button {
                plusPressed = true
                adjustLore(by: 1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { plusPressed = false }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(player.inkColor.color.opacity(plusPressed ? 0.4 : 0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(player.inkColor.color.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundColor(player.inkColor.color)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    customValue = player.lore
                    showCustomValuePicker = true
                }
            )
        }
        .padding(.horizontal, 4)
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
