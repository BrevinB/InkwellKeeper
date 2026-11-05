//
//  NotificationsOffSection.swift
//  Inkwell Keeper
//
//  Shown when notifications are denied, since alerts are silent without them.
//

import SwiftUI

struct NotificationsOffSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            VStack(alignment: .leading) {
                Label("Notifications are off", systemImage: "bell.slash.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("Your alerts are saved, but they can't reach you until notifications are allowed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            }
        }
    }
}
