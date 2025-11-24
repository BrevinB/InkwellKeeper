//
//  StatsView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI
import Combine

struct StatsView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    
    var body: some View {
        navigationWrapper {
            ScrollView {
                VStack(spacing: 24) {
                    let stats = collectionManager.getCollectionStats()
                    
                    CollectionOverviewCard(
                        totalCards: stats.cardCount,
                        totalValue: stats.totalValue
                    )
                    
                    RarityBreakdownCard(cardsByRarity: Array(stats.rarityBreakdown))
                    
                    RecentAdditionsCard(recentCards: Array(collectionManager.collectedCards.prefix(5)))
                    
                    SetCompletionCard(cards: collectionManager.collectedCards)
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("Collection Stats")
        }
    }

    @ViewBuilder
    private func navigationWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            content()
        } else {
            NavigationView {
                content()
            }
        }
    }
}
