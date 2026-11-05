//
//  CollectionAlertsSection.swift
//  Inkwell Keeper
//
//  Pro alerts that watch the whole collection: daily moves on owned cards and
//  a Sunday value recap. No per-card setup — they cover whatever is owned.
//

import SwiftUI

struct CollectionAlertsSection: View {
    let isSubscribed: Bool
    let onUnlock: () -> Void

    @Bindable private var service = PriceAlertService.shared

    var body: some View {
        Section {
            if isSubscribed {
                Toggle(isOn: Binding(
                    get: { service.moversEnabled },
                    set: { enable("moves", enabled: $0) { service.moversEnabled = $0 } }
                )) {
                    Label("Big moves on my cards", systemImage: "arrow.up.arrow.down")
                }

                if service.moversEnabled {
                    Picker("Notify at", selection: $service.moveThreshold) {
                        ForEach(PriceAlertRules.moveThresholds, id: \.self) { threshold in
                            Text("±\(threshold)%").tag(threshold)
                        }
                    }
                    .onChange(of: service.moveThreshold) { _, percent in
                        Analytics.send(.collectionAlertThresholdChanged(percent: percent))
                    }
                }

                Toggle(isOn: Binding(
                    get: { service.digestEnabled },
                    set: { enable("digest", enabled: $0) { service.digestEnabled = $0 } }
                )) {
                    Label("Weekly value recap", systemImage: "calendar")
                }
            } else {
                Button(action: onUnlock) {
                    HStack {
                        Label("Big moves & weekly recap", systemImage: "bell.badge")
                        Spacer()
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Color.lorcanaGold)
                    }
                }
            }
        } header: {
            Text("Collection Alerts")
        } footer: {
            Text("Moves only count when a card changes by at least $1, so cheap cards don't flood you. The recap arrives Sunday mornings.")
        }
    }

    private func enable(_ kind: String, enabled: Bool, apply: (Bool) -> Void) {
        apply(enabled)
        Analytics.send(.collectionAlertToggled(kind: kind, enabled: enabled))
        if enabled {
            Task { await service.requestAuthorization() }
        }
    }
}
