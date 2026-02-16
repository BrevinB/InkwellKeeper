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

    var body: some View {
        ZStack {
            LorcanaBackground()

            VStack(spacing: 32) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Text("Lore Counter")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Select number of players")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Player count buttons
                VStack(spacing: 16) {
                    ForEach([2, 3, 4], id: \.self) { count in
                        Button {
                            playerCount = count
                            showGame = true
                        } label: {
                            HStack {
                                Image(systemName: "person.\(count).fill")
                                    .font(.title2)
                                Text("\(count) Players")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.lorcanaDark.opacity(0.85))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.lorcanaGold.opacity(0.5), lineWidth: 2)
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 40)

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
            LorcanaBackground()

            // Player grid
            playerGrid
                .padding(.horizontal, 8)
                .padding(.top, 48)
                .padding(.bottom, 8)

            // Floating buttons
            VStack {
                HStack {
                    // Close button (top-left)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()

                    Spacer()

                    // Reset + History buttons (top-right)
                    HStack(spacing: 16) {
                        Button { showResetAlert = true } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title3)
                                .foregroundColor(.lorcanaGold)
                        }

                        Button { showHistory = true } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title3)
                                .foregroundColor(.lorcanaGold)
                        }
                    }
                    .padding()
                }

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

    // MARK: - Player Grid

    private var playerGrid: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
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

    // 2 players: vertical split, top rotated 180°
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

    // 4 players: 2×2, top row rotated
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
