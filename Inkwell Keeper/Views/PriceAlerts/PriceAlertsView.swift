//
//  PriceAlertsView.swift
//  Inkwell Keeper
//
//  Every price alert in one place: armed and triggered card alerts, plus the
//  Pro collection alerts.
//

import SwiftData
import SwiftUI

struct PriceAlertsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PriceAlert.createdAt, order: .reverse) private var alerts: [PriceAlert]
    @State private var editing: PriceAlertEditTarget?
    @State private var showingCardPicker = false
    /// The card picked for a new alert; its editor opens once the picker is gone.
    @State private var pickedCard: LorcanaCard?
    @State private var showingPaywall = false
    @State private var testMessage: String?
    @State private var isSendingTest = false

    private let service = PriceAlertService.shared
    private let subscriptionManager = SubscriptionManager.shared

    private var armed: [PriceAlert] { alerts.filter { !$0.isTriggered } }
    private var triggered: [PriceAlert] {
        alerts.filter(\.isTriggered).sorted { ($0.triggeredAt ?? .distantPast) > ($1.triggeredAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                if service.authorizationStatus == .denied {
                    NotificationsOffSection()
                }

                CollectionAlertsSection(isSubscribed: subscriptionManager.isSubscribed) {
                    showingPaywall = true
                }

                if alerts.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Card Alerts",
                            systemImage: "bell",
                            description: Text("Tap + to pick a card, or open any card and tap Price Alert under its price.")
                        )
                        Button("Watch a Card", systemImage: "plus") { showingCardPicker = true }
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Section {
                        ForEach(armed) { alert in
                            Button { edit(alert) } label: { PriceAlertRow(alert: alert) }
                                .tint(.primary)
                        }
                        .onDelete { offsets in delete(offsets.map { armed[$0] }) }
                    } header: {
                        Text("Watching")
                    } footer: {
                        if !subscriptionManager.isSubscribed {
                            Text("\(armed.count) of \(PriceAlertRules.freeAlertLimit) free alerts used. Pro removes the limit.")
                        }
                    }

                    if !triggered.isEmpty {
                        Section("Triggered") {
                            ForEach(triggered) { alert in
                                Button { edit(alert) } label: { PriceAlertRow(alert: alert) }
                                    .tint(.primary)
                                    .swipeActions(edge: .leading) {
                                        Button("Re-arm", systemImage: "bell.badge") { rearm(alert) }
                                            .tint(.lorcanaGold)
                                    }
                            }
                            .onDelete { offsets in delete(offsets.map { triggered[$0] }) }
                        }
                    }
                }

                if service.isAuthorized && (!alerts.isEmpty || service.collectionAlertsEnabled) {
                    Section {
                        Button {
                            Task { await sendTest() }
                        } label: {
                            HStack {
                                Label("Send Test Notification", systemImage: "paperplane")
                                Spacer()
                                if isSendingTest { ProgressView() }
                            }
                        }
                        .disabled(isSendingTest)
                    } footer: {
                        if let testMessage { Text(testMessage) }
                    }
                }
            }
            .navigationTitle("Price Alerts")
            .tint(.lorcanaGold)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Alert", systemImage: "plus") { showingCardPicker = true }
                }
            }
            .task {
                await service.refreshAuthorizationStatus()
                await service.sync()
            }
            .sheet(isPresented: $showingCardPicker, onDismiss: openPickedCard) {
                PriceAlertCardPicker { card in
                    pickedCard = card
                    showingCardPicker = false
                }
            }
            .sheet(item: $editing) { target in
                PriceAlertEditorView(card: target.card, alert: target.alert)
            }
            .sheet(isPresented: $showingPaywall) {
                RulesPaywallView(source: "priceAlerts")
            }
        }
    }

    private func edit(_ alert: PriceAlert) {
        guard let card = SetsDataManager.shared.getAllCards().first(where: { $0.id == alert.cardId }) else { return }
        editing = PriceAlertEditTarget(card: card.withVariant(alert.cardVariant), alert: alert)
    }

    private func openPickedCard() {
        guard let card = pickedCard else { return }
        pickedCard = nil
        editing = PriceAlertEditTarget.forCard(card, alerts: alerts.filter { $0.cardId == card.id })
    }

    private func rearm(_ alert: PriceAlert) {
        guard PriceAlertRules.canCreateAlert(armedCount: armed.count, isSubscribed: subscriptionManager.isSubscribed) else {
            Analytics.send(.priceAlertLimitHit)
            showingPaywall = true
            return
        }
        alert.rearm()
        try? modelContext.save()
        Analytics.send(.priceAlertRearmed)
        service.scheduleSync()
    }

    private func delete(_ doomed: [PriceAlert]) {
        for alert in doomed {
            modelContext.delete(alert)
            Analytics.send(.priceAlertDeleted)
        }
        try? modelContext.save()
        service.scheduleSync()
    }

    private func sendTest() async {
        isSendingTest = true
        testMessage = switch await service.sendTestNotification() {
        case "sent":
            String(localized: "Sent — it should arrive in a few seconds.")
        case "dry_run":
            String(localized: "The server isn't set up to send notifications yet, so nothing was delivered.")
        case "unregistered":
            String(localized: "Apple rejected this device's notification token. Reopen the app to register again.")
        case "failed":
            String(localized: "Apple didn't accept the notification. Try again in a moment.")
        default:
            String(localized: "Couldn't send a test right now. Check your connection and try again.")
        }
        isSendingTest = false
    }
}
