//
//  LoreCounterView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 2/14/26.
//

import SwiftUI

// MARK: - Landing View (Tab Content)

struct LoreCounterView: View {
    @State private var playerCount = 2
    @State private var showGame = false

    private let playerOptions: [(count: Int, icon: String, label: String)] = [
        (2, "person.2.fill", "2 Players"),
        (3, "person.3.fill", "3 Players"),
        (4, "person.line.dotted.person.fill", "4 Players")
    ]

    var body: some View {
        ZStack {
            LorcanaBackground()

            VStack(spacing: 0) {
                Spacer()

                // Lore icon + title
                VStack(spacing: 16) {
                    // Decorative lore symbol
                    ZStack {
                        Circle()
                            .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 2)
                            .frame(width: 80, height: 80)

                        Circle()
                            .stroke(Color.lorcanaGold.opacity(0.15), lineWidth: 1)
                            .frame(width: 100, height: 100)

                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundColor(.lorcanaGold)
                    }
                    .padding(.bottom, 8)

                    Text("Lore Counter")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Track lore for your game")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()
                    .frame(height: 48)

                // Player count buttons
                VStack(spacing: 14) {
                    ForEach(playerOptions, id: \.count) { option in
                        Button {
                            playerCount = option.count
                            showGame = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: option.icon)
                                    .font(.title3)
                                    .foregroundColor(.lorcanaGold)
                                    .frame(width: 32)

                                Text(option.label)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.lorcanaDark.opacity(0.9),
                                                Color.lorcanaDark.opacity(0.7)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.lorcanaGold.opacity(0.4),
                                                        Color.lorcanaGold.opacity(0.1)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showGame) {
            LoreGameView(playerCount: playerCount)
        }
    }
}

// MARK: - Fullscreen Game View

private struct LoreGameView: View {
    let playerCount: Int

    @Environment(\.dismiss) private var dismiss
    @State private var players: [PlayerLore] = []
    @State private var history: [LoreHistoryEntry] = []
    @State private var showResetAlert = false
    @State private var showHistory = false

    private let defaultInkColors: [InkColor] = [.amber, .sapphire, .emerald, .ruby]

    var body: some View {
        ZStack {
            // Dark base background (no animated particles during gameplay)
            Color.lorcanaDark.ignoresSafeArea()

            // Player grid
            playerGrid
                .padding(.horizontal, 6)
                .padding(.top, 44)
                .padding(.bottom, 6)

            // Floating control bar
            VStack {
                controlBar
                Spacer()
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .alert("Reset All?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { resetAll() }
        } message: {
            Text("All lore counters will be set to 0 and history will be cleared.")
        }
        .sheet(isPresented: $showHistory) {
            historySheet
        }
        .onAppear {
            if players.isEmpty {
                buildPlayers(count: playerCount)
            }
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack {
            // Close button
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            HStack(spacing: 12) {
                // Reset button
                Button { showResetAlert = true } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.lorcanaGold)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }

                // History button
                Button { showHistory = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.lorcanaGold)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Player Grid

    private var playerGrid: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 6
            switch playerCount {
            case 2:
                twoPlayerLayout(size: geo.size, spacing: spacing)
            case 3:
                threePlayerLayout(size: geo.size, spacing: spacing)
            default:
                fourPlayerLayout(size: geo.size, spacing: spacing)
            }
        }
    }

    // 2 players: vertical split, top rotated 180
    private func twoPlayerLayout(size: CGSize, spacing: CGFloat) -> some View {
        let cardHeight = (size.height - spacing) / 2
        return VStack(spacing: spacing) {
            if players.count >= 2 {
                playerCard(at: 0)
                    .frame(height: cardHeight)
                    .rotationEffect(.degrees(180))

                playerCard(at: 1)
                    .frame(height: cardHeight)
            }
        }
    }

    // 3 players: top 1 (rotated), bottom 2
    private func threePlayerLayout(size: CGSize, spacing: CGFloat) -> some View {
        let rowHeight = (size.height - spacing) / 2
        return VStack(spacing: spacing) {
            if players.count >= 3 {
                playerCard(at: 0)
                    .frame(height: rowHeight)
                    .rotationEffect(.degrees(180))

                HStack(spacing: spacing) {
                    playerCard(at: 1)
                    playerCard(at: 2)
                }
                .frame(height: rowHeight)
            }
        }
    }

    // 4 players: 2x2, top row rotated
    private func fourPlayerLayout(size: CGSize, spacing: CGFloat) -> some View {
        let rowHeight = (size.height - spacing) / 2
        return VStack(spacing: spacing) {
            if players.count >= 4 {
                HStack(spacing: spacing) {
                    playerCard(at: 0)
                        .rotationEffect(.degrees(180))
                    playerCard(at: 1)
                        .rotationEffect(.degrees(180))
                }
                .frame(height: rowHeight)

                HStack(spacing: spacing) {
                    playerCard(at: 2)
                    playerCard(at: 3)
                }
                .frame(height: rowHeight)
            }
        }
    }

    private func playerCard(at index: Int) -> some View {
        PlayerLoreCard(player: $players[index]) { oldVal, newVal in
            history.insert(
                LoreHistoryEntry(
                    playerName: players[index].name,
                    previousValue: oldVal,
                    newValue: newVal
                ),
                at: 0
            )
        }
    }

    // MARK: - History Sheet

    private var historySheet: some View {
        NavigationView {
            List {
                if history.isEmpty {
                    Text("No history yet")
                        .foregroundColor(.gray)
                } else {
                    ForEach(history) { entry in
                        HStack {
                            Text("\(entry.playerName): \(entry.previousValue) → \(entry.newValue)")
                                .foregroundColor(.white)
                            Spacer()
                            Text(entry.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .listRowBackground(Color.lorcanaDark)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.lorcanaDark)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showHistory = false }
                        .foregroundColor(.lorcanaGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !history.isEmpty {
                        Button("Clear") {
                            history.removeAll()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private func buildPlayers(count: Int) {
        var newPlayers: [PlayerLore] = []
        for i in 0..<count {
            if i < players.count {
                newPlayers.append(players[i])
            } else {
                newPlayers.append(PlayerLore(
                    name: "Player \(i + 1)",
                    inkColor: defaultInkColors[i]
                ))
            }
        }
        players = newPlayers
    }

    private func resetAll() {
        for i in players.indices {
            players[i].lore = 0
        }
        history.removeAll()
    }
}
