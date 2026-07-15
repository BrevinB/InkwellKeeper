//
//  CollectionEmptyStateContent.swift
//  Inkwell Keeper
//
//  Isolates the CloudSyncMonitor read to a small leaf view so a sync-status
//  toggle only re-renders this content, not all of CollectionView.
//

import SwiftUI

struct CollectionEmptyStateContent: View {
    @State private var syncMonitor = CloudSyncMonitor.shared

    let collectionIsEmpty: Bool
    let searchIsEmpty: Bool
    @Binding var showingManualAdd: Bool
    @Binding var showingBulkImport: Bool
    let onScanTapped: () -> Void
    let searchQuery: String

    var body: some View {
        if syncMonitor.isReceivingFromCloud && collectionIsEmpty && searchIsEmpty {
            // Fresh install still pulling the collection down from iCloud —
            // show a syncing state instead of "add your first card".
            CloudSyncingPlaceholderView()
        } else {
            EmptyCollectionView(
                showingManualAdd: $showingManualAdd,
                showingBulkImport: $showingBulkImport,
                onScanTapped: onScanTapped,
                searchQuery: searchQuery
            )
        }
    }
}
