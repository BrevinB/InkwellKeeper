//
//  CloudSyncMonitor.swift
//  Inkwell Keeper
//
//  Observes iCloud (CloudKit) sync activity so the UI can tell the user when
//  their collection is still downloading.
//

import SwiftUI
import CoreData

/// Tracks CloudKit sync activity surfaced by SwiftData's underlying
/// `NSPersistentCloudKitContainer`, exposing a simple flag the UI can show.
///
/// SwiftData drives iCloud sync through `NSPersistentCloudKitContainer`, which posts
/// `eventChangedNotification` for every setup / import / export event. An event whose
/// `endDate` is `nil` is still in progress; once it has an end date it has finished.
/// We treat active *setup* and *import* events as "receiving data from iCloud" — the
/// case where a freshly installed app can look empty for a few seconds before cards
/// stream in.
@MainActor
@Observable
final class CloudSyncMonitor {
    static let shared = CloudSyncMonitor()

    /// True while iCloud is setting up or importing records from the server.
    private(set) var isReceivingFromCloud = false

    /// Becomes true once the first import from iCloud finishes, letting callers tell
    /// "still syncing" apart from "genuinely empty".
    private(set) var hasCompletedInitialImport = false

    /// Identifiers of in-flight setup/import events, so overlapping events are counted correctly.
    private var activeEvents: Set<UUID> = []

    private init() {
        // Held for the app's lifetime (shared singleton); the `[weak self]` guard keeps
        // it safe to leave registered, so there's no deinit to unregister it.
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event
            else { return }
            // Posted on `.main`, so we are already on the main thread here.
            MainActor.assumeIsolated {
                self.handle(event)
            }
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        // Only setup + import represent data arriving from iCloud; ignore exports (uploads).
        guard event.type == .import || event.type == .setup else { return }

        if event.endDate == nil {
            activeEvents.insert(event.identifier)
        } else {
            activeEvents.remove(event.identifier)
            if event.type == .import, event.succeeded {
                hasCompletedInitialImport = true
            }
        }

        isReceivingFromCloud = !activeEvents.isEmpty
    }
}
