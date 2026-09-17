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
    /// One instance shared by every portfolio card, so the collection's price
    /// history is fetched once per visit rather than once per card.
    @State private var portfolio = PortfolioHistoryViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var isRefreshingPrices = false
    @State private var showingShareImage = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize ? .flexible() : .adaptive(minimum: 340), spacing: 20)], alignment: .leading, spacing: 20) {
                    let snapshot = viewModel.snapshot

                    StatsOverviewCard(snapshot: snapshot)

                    if snapshot.totalCards > 0 {
                        // Pro and free cards alternate rather than sitting in
                        // two blocks: a wall of locked cards at the top reads
                        // as a paywalled screen, and pairing each Pro card with
                        // the related free one (value over time next to top
                        // value, movers next to value by set) keeps the mix
                        // visible while the subjects still follow on.
                        PortfolioHistoryCard(
                            viewModel: portfolio,
                            isSubscribed: subscriptionManager.isSubscribed,
                            onUnlock: presentPaywall
                        )
                        TopValuableCardsCard(cards: snapshot.topValuable)
                        PortfolioMoversCard(
                            viewModel: portfolio,
                            isSubscribed: subscriptionManager.isSubscribed,
                            onUnlock: presentPaywall
                        )
                        ValueBySetCard(valueBySet: snapshot.valueBySet)
                        PortfolioExtremesCard(
                            viewModel: portfolio,
                            isSubscribed: subscriptionManager.isSubscribed,
                            onUnlock: presentPaywall
                        )
                        RarityDonutCard(counts: snapshot.rarityCounts)
                        PortfolioVariantSplitCard(
                            viewModel: portfolio,
                            isSubscribed: subscriptionManager.isSubscribed,
                            onUnlock: presentPaywall
                        )
                        SetCompletionCard(cards: collectionManager.collectedCards)
                        CostBasisCard(
                            summary: portfolio.costBasis,
                            entries: portfolio.costBasisEntries,
                            isSubscribed: subscriptionManager.isSubscribed,
                            onUnlock: presentPaywall
                        )
                        InkColorChartCard(counts: snapshot.inkColorCounts)
                        CollectionCostCurveCard(counts: snapshot.costCounts)
                        TypeBreakdownCard(counts: snapshot.typeCounts)
                        if snapshot.hasInkableData {
                            InkableRatioCard(
                                inkable: snapshot.inkableCount,
                                nonInkable: snapshot.nonInkableCount
                            )
                        }
                        RecentAdditionsCard(recentCards: snapshot.recentCards)
                    } else {
                        StatsEmptyCollectionCard()
                    }
                }
                .frame(maxWidth: 1400)
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(LorcanaBackground())
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Share", systemImage: "square.and.arrow.up") {
                        showingShareImage = true
                    }
                    .disabled(viewModel.snapshot.totalCards == 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh prices", systemImage: "arrow.clockwise", action: refreshPrices)
                        .disabled(isRefreshingPrices || collectionManager.collectedCards.isEmpty)
                }
            }
            .onAppear {
                viewModel.refresh(context: modelContext)
            }
            .task(id: collectionManager.collectedCards.count) {
                await portfolio.load(cards: ownedCards())
            }
            .sheet(isPresented: $showingPaywall) {
                RulesPaywallView(source: "portfolioHistory")
            }
            .onChange(of: collectionManager.collectedCards.count) { _, _ in
                viewModel.refresh(context: modelContext)
            }
            .sheet(isPresented: $showingShareImage) {
                ShareCardPresenter(
                    analyticsType: "stats",
                    qrPayload: AppLinks.appStoreURLString,
                    fileName: "InkwellKeeper-Collection"
                ) { _ in
                    StatsSummaryShareCardView(
                        snapshot: viewModel.snapshot,
                        currencyCode: PricingService.preferredCurrency
                    )
                }
            }
        }
    }

    private func presentPaywall() {
        // RulesPaywallView reports its own exposure on appear — sending it here
        // too would double-count this funnel.
        showingPaywall = true
    }

    /// Wishlisted rows are aspirational, not owned, so they stay out of the
    /// portfolio — the same filter StatsViewModel applies to the totals.
    private func ownedCards() -> [CollectedCard] {
        let descriptor = FetchDescriptor<CollectedCard>(
            predicate: #Predicate { $0.isWishlisted == false }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
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
