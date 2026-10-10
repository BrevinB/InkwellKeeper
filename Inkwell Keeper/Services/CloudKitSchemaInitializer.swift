//
//  CloudKitSchemaInitializer.swift
//  Inkwell Keeper
//
//  DEBUG only. Pushes the complete shape of every SwiftData model to the CloudKit
//  *Development* environment, so "Deploy Schema Changes" carries every field to
//  Production.
//
//  Why it's needed: CloudKit only learns a field when a record containing it is
//  synced. Fields that are usually empty (a binder's linked set, a deck box's deck,
//  a pulled card's origin pocket, a box's capacity) may never have been sent from a
//  development device — and Production can't create fields, so once released those
//  changes would silently fail to sync. Apple's documented fix for SwiftData is to
//  run `initializeCloudKitSchema` from a Core Data container built from the same
//  models, once, before deploying.
//

#if DEBUG
import CoreData
import SwiftData

enum CloudKitSchemaInitializer {
    enum Failure: LocalizedError {
        case modelUnavailable

        var errorDescription: String? { "Couldn't build a Core Data model from the SwiftData models." }
    }

    /// Every synced model — keep in step with `InkwellKeeperApp.makeContainer()`.
    nonisolated static let modelTypes: [any PersistentModel.Type] = [
        CollectedCard.self, CardSet.self, CollectionStats.self,
        PriceHistory.self, Deck.self, DeckCard.self,
        StorageContainer.self, StoredCard.self
    ]

    nonisolated static let containerIdentifier = "iCloud.co.brevinb.Inkwell-Keeper"

    /// The throwaway container, kept alive after the push. Tearing it down straight
    /// away makes Core Data hold the store open (and log "didn't tear down… retrying")
    /// while CloudKit finishes its own work; letting it live until the app quits avoids that.
    nonisolated(unsafe) private static var keptAlive: NSPersistentCloudKitContainer?

    /// Sends the full schema to CloudKit Development, off the main thread. Uses a
    /// throwaway local store, so the real collection isn't touched.
    static func initializeDevelopmentSchema() async throws {
        try await Task.detached(priority: .userInitiated) {
            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: modelTypes) else {
                throw Failure.modelUnavailable
            }
            let storeURL = URL.temporaryDirectory.appending(path: "cloudkit-schema-init-\(UUID().uuidString).sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
            description.shouldAddStoreAsynchronously = false

            let container = NSPersistentCloudKitContainer(name: "SchemaInitializer", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var loadError: Error?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError { throw loadError }

            try container.initializeCloudKitSchema(options: [])
            keptAlive = container
        }.value
    }
}
#endif
