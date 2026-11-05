//
//  PriceAlertService.swift
//  Inkwell Keeper
//
//  Owns everything price alerts need outside the views: notification
//  permission, the APNs token, and keeping the pricing backend in step with
//  the alerts in SwiftData. The backend evaluates alerts once a day and pushes
//  in the device's local morning; this service uploads what to watch and reads
//  back which alerts fired.
//

import Foundation
import RevenueCat
import SwiftData
import UIKit
import UserNotifications

@MainActor
@Observable
final class PriceAlertService {
    static let shared = PriceAlertService()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var isSyncing = false
    private(set) var lastSyncFailed = false
    /// A link from a tapped notification, waiting for the UI to route it.
    var pendingNotificationURL: URL?

    // MARK: Collection alerts (Pro)

    var moversEnabled: Bool {
        didSet { defaults.set(moversEnabled, forKey: Keys.moversEnabled); scheduleSync() }
    }

    var moveThreshold: Int {
        didSet { defaults.set(moveThreshold, forKey: Keys.moveThreshold); scheduleSync() }
    }

    var digestEnabled: Bool {
        didSet { defaults.set(digestEnabled, forKey: Keys.digestEnabled); scheduleSync() }
    }

    var collectionAlertsEnabled: Bool { moversEnabled || digestEnabled }

    // MARK: Private state

    private enum Keys {
        static let moversEnabled = "priceAlerts.moversEnabled"
        static let moveThreshold = "priceAlerts.moveThreshold"
        static let digestEnabled = "priceAlerts.digestEnabled"
        static let deviceToken = "priceAlerts.deviceToken"
        static let isRegistered = "priceAlerts.isRegistered"
        static let holdingsSignature = "priceAlerts.holdingsSignature"
        static let ignoredWishlistOffers = "priceAlerts.ignoredWishlistOffers"
    }

    private let defaults = UserDefaults.standard
    private let client = PriceAlertClient()
    private var container: ModelContainer?
    private var pendingSync: Task<Void, Never>?

    private var deviceToken: String? {
        get { defaults.string(forKey: Keys.deviceToken) }
        set { defaults.set(newValue, forKey: Keys.deviceToken) }
    }

    private init() {
        moversEnabled = defaults.bool(forKey: Keys.moversEnabled)
        let storedThreshold = defaults.integer(forKey: Keys.moveThreshold)
        moveThreshold = PriceAlertRules.moveThresholds.contains(storedThreshold)
            ? storedThreshold
            : PriceAlertRules.defaultMoveThreshold
        digestEnabled = defaults.bool(forKey: Keys.digestEnabled)
    }

    // MARK: Wishlist offer

    /// The card to offer an alert on after it was added to the wishlist, or
    /// nil when it already has one or the user keeps waving the offer off.
    func wishlistOfferCandidate(_ card: LorcanaCard) -> LorcanaCard? {
        let cardId = card.id
        let existing = (try? container?.mainContext.fetchCount(
            FetchDescriptor<PriceAlert>(predicate: #Predicate { $0.cardId == cardId })
        )) ?? 0
        let offer = PriceAlertRules.shouldOfferWishlistAlert(
            hasAlert: existing > 0,
            ignoredOffers: defaults.integer(forKey: Keys.ignoredWishlistOffers)
        )
        return offer ? card : nil
    }

    func recordWishlistOffer(accepted: Bool) {
        if accepted {
            defaults.set(0, forKey: Keys.ignoredWishlistOffers)
        } else {
            defaults.set(defaults.integer(forKey: Keys.ignoredWishlistOffers) + 1, forKey: Keys.ignoredWishlistOffers)
            Analytics.send(.priceAlertOfferDismissed)
        }
    }

    func configure(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Permission

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if isAuthorized {
            // Tokens can change (restore from backup, reinstall); APNs hands
            // back the current one cheaply.
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Asks for permission the first time an alert is created; afterwards
    /// returns the standing answer.
    @discardableResult
    func requestAuthorization() async -> Bool {
        if authorizationStatus == .notDetermined {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            Analytics.send(.priceAlertPermissionAnswered(granted: granted))
        }
        await refreshAuthorizationStatus()
        return isAuthorized
    }

    func didRegister(deviceToken data: Data) {
        let token = data.map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
        guard token != deviceToken else { return }
        deviceToken = token
        scheduleSync()
    }

    func didOpenNotification(deeplink: String?, kind: String) {
        Analytics.send(.priceAlertOpened(kind: kind))
        if let deeplink, let url = URL(string: deeplink) {
            pendingNotificationURL = url
        }
    }

    // MARK: - Sync

    /// Coalesces bursts of edits into one upload.
    func scheduleSync() {
        pendingSync?.cancel()
        pendingSync = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await sync()
        }
    }

    /// Uploads alerts and settings, applies fires the backend reports, and
    /// refreshes holdings for collection alerts when they changed.
    func sync() async {
        guard let context = container?.mainContext, !isSyncing else { return }
        let alerts = (try? context.fetch(FetchDescriptor<PriceAlert>())) ?? []
        let installId = InstallIdentifier.current
        let isRegistered = defaults.bool(forKey: Keys.isRegistered)

        // Nothing to watch: forget the device so it stops being evaluated.
        if alerts.isEmpty && !collectionAlertsEnabled {
            guard isRegistered else { return }
            isSyncing = true
            defer { isSyncing = false }
            do {
                try await client.unregister(installId: installId)
                defaults.set(false, forKey: Keys.isRegistered)
                defaults.removeObject(forKey: Keys.holdingsSignature)
                lastSyncFailed = false
            } catch {
                lastSyncFailed = true
            }
            return
        }

        guard isAuthorized, let deviceToken else { return }
        isSyncing = true
        defer { isSyncing = false }

        let request = PriceAlertSync.DeviceRequest(
            apnsToken: deviceToken,
            apnsEnv: Self.apnsEnvironment,
            rcUserId: Purchases.isConfigured ? Purchases.shared.appUserID : nil,
            timezone: TimeZone.current.identifier,
            moversEnabled: moversEnabled,
            moveThresholdPct: moveThreshold,
            digestEnabled: digestEnabled,
            targets: alerts.map(PriceAlertSync.Target.init)
        )
        do {
            let response = try await client.syncDevice(installId: installId, request)
            defaults.set(true, forKey: Keys.isRegistered)
            if PriceAlertRules.reconcile(alerts, with: response.fired) > 0 {
                try? context.save()
            }
            try await syncHoldings(installId: installId, context: context)
            lastSyncFailed = false
        } catch {
            print("[PriceAlerts] sync failed: \(error)")
            lastSyncFailed = true
        }
    }

    private func syncHoldings(installId: String, context: ModelContext) async throws {
        guard collectionAlertsEnabled, SubscriptionManager.shared.isSubscribed else { return }
        let owned = (try? context.fetch(FetchDescriptor<CollectedCard>(
            predicate: #Predicate { $0.isWishlisted == false }
        ))) ?? []
        let holdings = PriceAlertSync.holdings(from: owned) { PricingService.shared.priceKey(for: $0) }
        let signature = PriceAlertSync.signature(of: holdings)
        guard signature != defaults.string(forKey: Keys.holdingsSignature) else { return }
        try await client.replaceHoldings(installId: installId, holdings)
        defaults.set(signature, forKey: Keys.holdingsSignature)
    }

    /// Asks the backend to push to this device.
    /// - Returns: The backend's result: "sent", "dry_run" (no APNs key is
    ///   configured, so nothing reached Apple), "failed" or "unregistered";
    ///   nil when the device couldn't register or the request failed.
    func sendTestNotification() async -> String? {
        await sync()
        guard defaults.bool(forKey: Keys.isRegistered) else { return nil }
        return try? await client.sendTestPush(installId: InstallIdentifier.current)
    }

    /// Debug builds talk to the APNs sandbox; TestFlight and App Store builds
    /// are signed for production.
    private static var apnsEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}
