//
//  TradeCalculatorView.swift
//  Inkwell Keeper
//
//  Values both halves of a trade so a collector can see who is ahead before
//  they agree to it.
//

import SwiftUI

struct TradeCalculatorView: View {
    @EnvironmentObject private var collectionManager: CollectionManager
    @State private var viewModel = TradeCalculatorViewModel()
    @State private var addingTo: TradeCalculatorViewModel.Side?
    @State private var scanningInto: TradeCalculatorViewModel.Side?
    @State private var showingConfirm = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if subscriptionManager.isSubscribed {
                    tradeContent
                } else {
                    // The paywall reports its own exposure on appear.
                    TradeCalculatorLockedView { showingPaywall = true }
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Trade Calculator")
            .toolbar {
                if subscriptionManager.isSubscribed && !viewModel.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", systemImage: "trash", action: viewModel.clear)
                    }
                }
            }
            .sheet(item: $addingTo) { side in
                TradeCardPicker { card in
                    viewModel.add(card, to: side)
                    addingTo = nil
                }
                .environmentObject(collectionManager)
            }
            .sheet(item: $scanningInto) { side in
                TradeScannerSheet(sideTitle: side.title) { card in
                    viewModel.add(card, to: side)
                }
            }
            .sheet(isPresented: $showingConfirm) {
                TradeConfirmationView(
                    yours: viewModel.yours,
                    theirs: viewModel.theirs,
                    difference: viewModel.difference
                )
            }
            .sheet(isPresented: $showingPaywall) {
                RulesPaywallView(source: "tradeCalculator")
            }
        }
    }

    private var tradeContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                TradeVerdictCard(viewModel: viewModel)

                ForEach(TradeCalculatorViewModel.Side.allCases) { side in
                    TradeSideSection(
                        side: side,
                        tradeSide: side == .yours ? viewModel.yours : viewModel.theirs,
                        isPricing: viewModel.isPricing,
                        onAdd: { addingTo = side },
                        onScan: { scanningInto = side },
                        onRemove: { viewModel.remove($0, from: side) }
                    )
                }

                if viewModel.canConfirm {
                    Button("Confirm trade", systemImage: "checkmark.seal") {
                        showingConfirm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.lorcanaGold)
                    .foregroundStyle(.black)
                }
            }
            .padding()
            // The iOS 26 tab bar floats over scrolling content, which left the
            // confirm button unreachable until the view was scrolled.
            .safeAreaPadding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

private struct TradeCalculatorLockedView: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.lorcanaGold)

            Text("Know who's ahead before you trade")
                .font(.title3)
                .bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Build both sides of a trade and see the market value of each, side by side.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Unlock with Pro", systemImage: "sparkles", action: onUnlock)
                .buttonStyle(.borderedProminent)
                .tint(.lorcanaGold)
                .foregroundStyle(.black)
            Spacer()
        }
    }
}
