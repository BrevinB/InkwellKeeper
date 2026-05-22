//
//  StatsView.swift
//  Inkwell Keeper
//
//  Collection analytics: chart-driven overview of what the user owns and what it's worth.
//

import SwiftUI
import SwiftData

struct StatsView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = StatsViewModel()
    @State private var isRefreshingPrices = false

    var body: some View {
        navigationWrapper {
            ScrollView {
                LazyVStack(spacing: 20) {
                    let snapshot = viewModel.snapshot

                    StatsOverviewCard(snapshot: snapshot)

                    if snapshot.totalCards > 0 {
                        RarityDonutCard(counts: snapshot.rarityCounts)
                        InkColorChartCard(counts: snapshot.inkColorCounts)
                        CollectionCostCurveCard(counts: snapshot.costCounts)
                        TypeBreakdownCard(counts: snapshot.typeCounts)
                        if snapshot.hasInkableData {
                            InkableRatioCard(
                                inkable: snapshot.inkableCount,
                                nonInkable: snapshot.nonInkableCount
                            )
                        }
                        TopValuableCardsCard(cards: snapshot.topValuable)
                        ValueBySetCard(valueBySet: snapshot.valueBySet)
                        SetCompletionCard(cards: collectionManager.collectedCards)
                        RecentAdditionsCard(recentCards: snapshot.recentCards)
                    } else {
                        StatsEmptyCollectionCard()
                    }
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh prices", systemImage: "arrow.clockwise", action: refreshPrices)
                        .disabled(isRefreshingPrices || collectionManager.collectedCards.isEmpty)
                }
            }
            .onAppear {
                viewModel.refresh(context: modelContext)
            }
            .onChange(of: collectionManager.collectedCards.count) { _, _ in
                viewModel.refresh(context: modelContext)
            }
        }
    }

    private func refreshPrices() {
        guard !isRefreshingPrices else { return }
        isRefreshingPrices = true
        Task {
            await collectionManager.refreshAllPrices()
            viewModel.refresh(context: modelContext)
            isRefreshingPrices = false
        }
    }

    @ViewBuilder
    private func navigationWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content()
        } else {
            NavigationStack {
                content()
            }
        }
    }
}

private struct StatsEmptyCollectionCard: View {
    var body: some View {
        StatsCardContainer(title: "No cards yet") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scan or import cards to see your collection analytics — rarity, ink colors, cost curve, and top-value cards will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
        }
    }
}
