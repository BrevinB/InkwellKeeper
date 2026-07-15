//
//  CloudSyncOverlay.swift
//  Inkwell Keeper
//
//  Isolates the CloudSyncMonitor read to a small leaf view so a sync-status
//  toggle only re-renders this overlay, not whatever root view it's attached to.
//

import SwiftUI

struct CloudSyncOverlay: View {
    @State private var syncMonitor = CloudSyncMonitor.shared

    var body: some View {
        VStack {
            if syncMonitor.isReceivingFromCloud {
                CloudSyncBanner()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: syncMonitor.isReceivingFromCloud)
    }
}

#Preview {
    ZStack {
        Color.lorcanaDark.ignoresSafeArea()
        CloudSyncOverlay()
    }
}
