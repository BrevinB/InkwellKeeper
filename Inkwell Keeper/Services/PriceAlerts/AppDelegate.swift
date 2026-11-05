//
//  AppDelegate.swift
//  Inkwell Keeper
//
//  The minimum UIKit delegate SwiftUI still needs for remote notifications:
//  receiving the APNs device token and handling taps on delivered pushes.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PriceAlertService.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[PriceAlerts] APNs registration failed: \(error.localizedDescription)")
    }

    // These use the completion-handler forms on purpose. The async forms
    // return through a background executor, so UIKit gets its completion
    // called off the main thread and the app crashes when a push is tapped.

    /// Shows alerts that arrive while the app is open, rather than dropping them.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let deeplink = content.userInfo["deeplink"] as? String
        let kind = content.threadIdentifier
        Task { @MainActor in
            PriceAlertService.shared.didOpenNotification(deeplink: deeplink, kind: kind)
            // Something may have fired; pick up the triggered state.
            PriceAlertService.shared.scheduleSync()
        }
        completionHandler()
    }
}
