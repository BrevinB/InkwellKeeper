//
//  PriceAlertEditorView.swift
//  Inkwell Keeper
//
//  Creates or edits a price alert for one printing: pick a drop or a rise,
//  then set the target by preset, by nudging, by typing or by dragging the
//  target line across the card's price history.
//

import SwiftData
import SwiftUI
import TipKit

struct PriceAlertEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(filter: #Predicate<PriceAlert> { $0.triggeredAt == nil }) private var armedAlerts: [PriceAlert]
    @State private var model: PriceAlertEditorModel
    @State private var showingPaywall = false
    @State private var showingNotificationsOff = false
    @State private var showingDeleteConfirmation = false
    @State private var isSaving = false

    init(card: LorcanaCard, alert: PriceAlert? = nil, source: String) {
        _model = State(initialValue: PriceAlertEditorModel(card: card, alert: alert, source: source))
    }

    private var saveTitle: String {
        guard let alert = model.alert else { return String(localized: "Set Alert") }
        return alert.isTriggered ? String(localized: "Re-arm Alert") : String(localized: "Update Alert")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PriceAlertCardHeader(model: model)
                    PriceAlertDirectionPicker(selection: $model.direction)
                    PriceAlertTargetPanel(model: model)
                    PriceAlertEditorFooter(model: model)
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(LorcanaBackground())
            .safeAreaInset(edge: .bottom) {
                PriceAlertSaveBar(
                    title: saveTitle,
                    freeAlertsRemaining: model.addsArmedAlert
                        ? model.freeAlertsRemaining(
                            armedCount: armedAlerts.count,
                            isSubscribed: SubscriptionManager.shared.isSubscribed
                        )
                        : nil,
                    isEnabled: model.isValid && !isSaving
                ) {
                    Task { await save() }
                }
            }
            .navigationTitle(model.isEditing ? "Edit Alert" : "New Price Alert")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.lorcanaGold)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if model.isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Delete Alert", systemImage: "trash", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .task { await model.loadPriceHistory() }
            .onAppear {
                Analytics.send(.priceAlertEditorOpened(source: model.source, existing: model.isEditing))
            }
            .sheet(isPresented: $showingPaywall) {
                RulesPaywallView(source: "priceAlerts")
            }
            .confirmationDialog("Delete this alert?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Alert", role: .destructive, action: delete)
            }
            .alert("Notifications Are Off", isPresented: $showingNotificationsOff) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                    dismiss()
                }
                Button("Not Now", role: .cancel) { dismiss() }
            } message: {
                Text("Your alert is saved, but you won't hear about it until notifications are allowed for Inkwell Keeper.")
            }
        }
    }

    private func delete() {
        guard let alert = model.alert else { return }
        modelContext.delete(alert)
        try? modelContext.save()
        Analytics.send(.priceAlertDeleted)
        PriceAlertService.shared.scheduleSync()
        dismiss()
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let outcome = model.save(
            in: modelContext,
            armedCount: armedAlerts.count,
            isSubscribed: SubscriptionManager.shared.isSubscribed
        )
        guard outcome == .saved else {
            showingPaywall = true
            return
        }

        // Someone who set an alert has found the bell; stop pointing at it.
        PriceAlertBellTip().invalidate(reason: .actionPerformed)

        let service = PriceAlertService.shared
        let allowed = await service.requestAuthorization()
        service.scheduleSync()
        if allowed {
            dismiss()
        } else {
            showingNotificationsOff = true
        }
    }
}
