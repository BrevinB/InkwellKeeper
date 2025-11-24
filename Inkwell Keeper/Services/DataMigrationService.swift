//
//  DataMigrationService.swift
//  Inkwell Keeper
//
//  Created by Claude on 11/22/25.
//
//  Smart migration service to preserve user collections when updating card data

import Foundation
import SwiftData
import Combine

/// Result of a migration operation
struct MigrationResult {
    let totalCards: Int
    let successfulMigrations: Int
    let failedMigrations: Int
    let preservedCards: Int
    let migratedCards: [(oldId: String, newId: String, method: String)]
    let unmatchedCards: [(cardName: String, setName: String)]

    var successRate: Double {
        guard totalCards > 0 else { return 0 }
        return Double(successfulMigrations) / Double(totalCards) * 100
    }
}

/// Service for migrating user collections to new card data format
class DataMigrationService {
    static let shared = DataMigrationService()

    private init() {}

    /// Codable representation for backup import/export
    private struct BackupCollectedCard: Codable {
        let cardId: String
        let name: String
        let setName: String
        let uniqueId: String
        let variant: String
        let quantity: Int
        let dateAdded: Date
        let isWishlisted: Bool
    }

    /// Perform migration of user's collected cards to new card IDs
    /// Uses three-tier matching: uniqueId → name+set+variant → name+set
    func migrateUserCollection(
        context: ModelContext,
        migrationMapPath: String = "Inkwell Keeper/Data/migration_map.json",
        dataManager: SetsDataManager
    ) async throws -> MigrationResult {
        print("🔄 Starting collection migration...")

        // Load migration map
        guard let migrationData = loadMigrationMap(path: migrationMapPath) else {
            throw MigrationError.invalidMigrationMap
        }

        let mappings = migrationData["mappings"] as? [String: [String: Any]] ?? [:]

        // Fetch all collected cards
        let descriptor = FetchDescriptor<CollectedCard>()
        let collectedCards = try context.fetch(descriptor)

        print("   Found \(collectedCards.count) cards in collection")

        var successCount = 0
        var failCount = 0
        var preserveCount = 0
        var migratedCards: [(String, String, String)] = []
        var unmatchedCards: [(String, String)] = []

        // Process each collected card
        for collected in collectedCards {
            let cardName = collected.name ?? "Unknown"
            let setName = collected.setName ?? "Unknown"
            let oldId = collected.cardId ?? ""
            let oldUniqueId = collected.uniqueId ?? ""
            let variant = CardVariant(rawValue: collected.variant ?? "Normal") ?? .normal

            // Try to find matching new card
            var newCard: LorcanaCard? = nil
            var matchMethod = ""

            // Strategy 1: Match by old ID in migration map
            if let mapping = mappings[oldId] as? [String: Any],
               let newId = mapping["new_id"] as? String {
                // Find new card by new ID
                newCard = findCardById(newId, in: dataManager)
                matchMethod = mapping["match_method"] as? String ?? "migration_map"
            }

            // Strategy 2: Match by uniqueId + variant
            if newCard == nil && !oldUniqueId.isEmpty {
                newCard = findCardByUniqueId(oldUniqueId, variant: variant, in: dataManager)
                matchMethod = "uniqueId"
            }

            // Strategy 3: Match by name + set + variant
            if newCard == nil {
                newCard = findCardByNameAndSet(cardName, setName: setName, variant: variant, in: dataManager)
                matchMethod = "name+set+variant"
            }

            // Strategy 4: Match by name + set (ignore variant) - fallback for Normal/Foil
            if newCard == nil && (variant == .normal || variant == .foil) {
                newCard = findCardByNameAndSet(cardName, setName: setName, variant: .normal, in: dataManager)
                    ?? findCardByNameAndSet(cardName, setName: setName, variant: .foil, in: dataManager)
                matchMethod = "name+set"
            }

            // Update or preserve
            if let newCard = newCard {
                // Migrate to new card data
                collected.cardId = newCard.id
                collected.name = newCard.name
                collected.setName = newCard.setName
                collected.uniqueId = newCard.uniqueId
                collected.variant = newCard.variant.rawValue
                collected.imageUrl = newCard.imageUrl
                collected.rarity = newCard.rarity.rawValue

                successCount += 1
                migratedCards.append((oldId, newCard.id, matchMethod))

                print("   ✅ Migrated: \(cardName) (\(matchMethod))")
            } else {
                // No match found - preserve existing data
                preserveCount += 1
                failCount += 1
                unmatchedCards.append((cardName, setName))

                print("   ⚠️  Preserved (no match): \(cardName) from \(setName)")
            }
        }

        // Save changes
        try context.save()

        let result = MigrationResult(
            totalCards: collectedCards.count,
            successfulMigrations: successCount,
            failedMigrations: failCount,
            preservedCards: preserveCount,
            migratedCards: migratedCards,
            unmatchedCards: unmatchedCards
        )

        print()
        print("✅ Migration complete!")
        print("   Total: \(result.totalCards)")
        print("   Migrated: \(result.successfulMigrations) (\(String(format: "%.1f", result.successRate))%)")
        print("   Preserved: \(result.preservedCards)")

        return result
    }

    /// Create a backup of the current database state
    func createBackup(context: ModelContext) throws -> URL {
        print("💾 Creating database backup...")

        let backupDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups")

        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupFile = backupDir.appendingPathComponent("collection_backup_\(timestamp).json")

        // Export all collected cards to JSON
        let descriptor = FetchDescriptor<CollectedCard>()
        let cards = try context.fetch(descriptor)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let exportData: [BackupCollectedCard] = cards.map { card in
            BackupCollectedCard(
                cardId: card.cardId ?? "",
                name: card.name ?? "",
                setName: card.setName ?? "",
                uniqueId: card.uniqueId ?? "",
                variant: card.variant ?? "Normal",
                quantity: card.quantity,
                dateAdded: card.dateAdded ?? Date(),
                isWishlisted: card.isWishlisted
            )
        }

        let jsonData = try encoder.encode(exportData)
        try jsonData.write(to: backupFile)

        print("   ✅ Backup saved to: \(backupFile.lastPathComponent)")

        return backupFile
    }

    /// Restore collection from backup
    func restoreFromBackup(context: ModelContext, backupURL: URL) throws {
        print("♻️ Restoring from backup...")

        let jsonData = try Data(contentsOf: backupURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupData = try decoder.decode([BackupCollectedCard].self, from: jsonData)

        // Clear existing cards
        let descriptor = FetchDescriptor<CollectedCard>()
        let existingCards = try context.fetch(descriptor)
        for card in existingCards {
            context.delete(card)
        }

        // Restore from backup
        for item in backupData {
            // Many fields are defaulted because backups contain a reduced schema
            let card = CollectedCard(
                cardId: item.cardId,
                name: item.name,
                cost: 0,
                type: "",
                rarity: .common,
                setName: item.setName,
                cardText: "",
                imageUrl: "",
                price: 0,
                quantity: item.quantity,
                condition: "Near Mint",
                isWishlisted: item.isWishlisted,
                notes: "",
                variant: CardVariant(rawValue: item.variant) ?? .normal,
                inkColor: nil,
                uniqueId: item.uniqueId,
                cardNumber: nil
            )
            context.insert(card)
        }

        try context.save()

        print("   ✅ Restored \(backupData.count) cards")
    }

    // MARK: - Helper Methods

    private func loadMigrationMap(path: String) -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: path.replacingOccurrences(of: ".json", with: ""), withExtension: "json") else {
            print("   ⚠️  Migration map not found at: \(path)")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json
        } catch {
            print("   ❌ Error loading migration map: \(error)")
            return nil
        }
    }

    private func findCardById(_ id: String, in dataManager: SetsDataManager) -> LorcanaCard? {
        let allCards = dataManager.getAllCards()
        return allCards.first { $0.id == id }
    }

    private func findCardByUniqueId(_ uniqueId: String, variant: CardVariant, in dataManager: SetsDataManager) -> LorcanaCard? {
        let allCards = dataManager.getAllCards()

        // For Epic/Iconic/Enchanted/Promo, match variant strictly
        let variantsAreSeparateCards = variant == .epic || variant == .iconic || variant == .enchanted || variant == .promo

        if variantsAreSeparateCards {
            return allCards.first { $0.uniqueId == uniqueId && $0.variant == variant }
        } else {
            // For Normal/Foil, ignore variant (same card)
            return allCards.first { $0.uniqueId == uniqueId }
        }
    }

    private func findCardByNameAndSet(_ name: String, setName: String, variant: CardVariant, in dataManager: SetsDataManager) -> LorcanaCard? {
        let allCards = dataManager.getAllCards()

        return allCards.first { card in
            guard card.name.lowercased() == name.lowercased(),
                  card.setName.lowercased() == setName.lowercased() else {
                return false
            }

            // For Epic/Iconic/Enchanted/Promo, match variant strictly
            let variantsAreSeparateCards = variant == .epic || variant == .iconic || variant == .enchanted || variant == .promo

            if variantsAreSeparateCards {
                return card.variant == variant
            } else {
                // For Normal/Foil, accept any variant
                return true
            }
        }
    }
}

/// Migration errors
enum MigrationError: Error {
    case invalidMigrationMap
    case backupFailed
    case restoreFailed
}

