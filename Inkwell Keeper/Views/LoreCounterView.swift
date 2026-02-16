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
    @State private var showSetup = false
    @State private var showGame = false
    @State private var players: [PlayerLore] = []

    private let playerOptions: [(count: Int, icon: String, label: String)] = [
        (2, "person.2.fill", "2 Players"),
        (3, "person.3.fill", "3 Players"),
        (4, "person.line.dotted.person.fill", "4 Players")
    ]

    private let defaultInkColors: [InkColor] = [.amber, .sapphire, .emerald, .ruby]

    var body: some View {
        ZStack {
            LorcanaBackground()

            if showSetup {
                setupView
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                landingView
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showGame) {
            LoreGameView(initialPlayers: players)
        }
    }

    // MARK: - Landing View

    private var landingView: some View {
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
                        buildPlayers(count: option.count)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSetup = true
                        }
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

    // MARK: - Setup View

    private var setupView: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSetup = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Back")
                            .font(.body)
                    }
                    .foregroundColor(.lorcanaGold)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 24) {
                Text("Choose Your Ink")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Select a color for each player")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))

                VStack(spacing: 16) {
                    ForEach(players.indices, id: \.self) { index in
                        playerSetupRow(at: index)
                    }
                }
                .padding(.top, 8)
            }

            Spacer()

            // Start Game button
            Button {
                showGame = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.body.weight(.semibold))

                    Text("Start Game")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .foregroundColor(.lorcanaDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.lorcanaGold)
                )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func playerSetupRow(at index: Int) -> some View {
        HStack(spacing: 16) {
            // Player name
            Text(players[index].name)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 90, alignment: .leading)

            Spacer()

            // Color dots
            HStack(spacing: 12) {
                ForEach(InkColor.allCases, id: \.self) { ink in
                    let isSelected = players[index].inkColor == ink
                    ZStack {
                        Circle()
                            .fill(ink.color.opacity(isSelected ? 1.0 : 0.4))
                            .frame(width: isSelected ? 28 : 22, height: isSelected ? 28 : 22)

                        if isSelected {
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 2.5)
                                .frame(width: 34, height: 34)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            players[index].inkColor = ink
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(players[index].inkColor.color.opacity(0.4), lineWidth: 1)
                )
        )
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private func buildPlayers(count: Int) {
        players = (0..<count).map { i in
            PlayerLore(
                name: "Player \(i + 1)",
                inkColor: defaultInkColors[i % defaultInkColors.count]
            )
        }
    }
}

// MARK: - Fullscreen Game View

private struct LoreGameView: View {
    let initialPlayers: [PlayerLore]

    @Environment(\.dismiss) private var dismiss
    @State private var players: [PlayerLore] = []
    @State private var history: [LoreHistoryEntry] = []
    @State private var showResetAlert = false
    @State private var showHistory = false
    @State private var topSafeArea: CGFloat = 0

    private var playerCount: Int { players.count }

    var body: some View {
        ZStack {
            // Dark base background (no animated particles during gameplay)
            Color.lorcanaDark.ignoresSafeArea()

            // Player grid
            playerGrid
                .padding(.horizontal, 6)
                .padding(.top, topSafeArea + 6)
                .padding(.bottom, 6)

            // Floating options button (right edge, between player areas)
            HStack {
                Spacer()
                optionsButton
                    .padding(.trailing, 12)
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
                players = initialPlayers
            }
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                topSafeArea = window.safeAreaInsets.top
            }
        }
    }

    // MARK: - Options Button

    private var optionsButton: some View {
        Menu {
            Button {
                showHistory = true
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            Divider()

            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label("Reset All", systemImage: "arrow.counterclockwise")
            }

            Button {
                dismiss()
            } label: {
                Label("Exit Game", systemImage: "xmark")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.footnote.weight(.bold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        }
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

    private func resetAll() {
        for i in players.indices {
            players[i].lore = 0
        }
        history.removeAll()
    }
}
