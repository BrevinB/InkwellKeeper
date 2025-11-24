//
//  ImportService.swift
//  Inkwell Keeper
//
//  Handles bulk importing from various sources (CSV, text lists, etc.)
//

import Foundation

class ImportService {
    static let shared = ImportService()

    private let dataManager = SetsDataManager.shared

    private init() {}

    // MARK: - Import Result Types

    struct ImportResult {
        let successful: [ImportedCard]
        let failed: [FailedImport]
        let duplicates: [ImportedCard]

        var totalProcessed: Int {
            successful.count + failed.count + duplicates.count
        }

        var successRate: Double {
            guard totalProcessed > 0 else { return 0 }
            return Double(successful.count) / Double(totalProcessed) * 100
        }

        // Number of unique cards (distinct card+variant combinations being imported)
        var uniqueCardsCount: Int {
            // Count unique card+variant combinations (not just card IDs)
            // This handles cases where a card has both normal and foil variants
            let uniqueCombinations = Set(successful.map { "\($0.card.id)_\($0.card.variant.rawValue)" })
            return uniqueCombinations.count
        }

        // Total number of physical cards being added (sum of all quantities)
        var totalCardsCount: Int {
            successful.reduce(0) { $0 + $1.quantity }
        }

        // Total number of cards that failed to import (sum of quantities from failed imports)
        var totalFailedCardsCount: Int {
            failed.count // Each failed line represents one unique card attempt
        }

        // Number of CSV rows processed
        var rowsProcessed: Int {
            let successfulLines = Set(successful.map { $0.originalLine })
            let failedLines = Set(failed.map { $0.originalLine })
            return successfulLines.union(failedLines).count
        }
    }

    struct ImportedCard {
        let card: LorcanaCard
        let quantity: Int
        let originalLine: String
    }

    struct FailedImport {
        let originalLine: String
        let reason: String
    }

    enum ImportFormat {
        case csv              // CSV with headers
        case textList         // Simple text list (one per line)
        case dreamborn        // Dreamborn.ink format
        case lorcanaHQ        // Lorcana HQ format

        var description: String {
            switch self {
            case .csv: return "CSV File"
            case .textList: return "Text List"
            case .dreamborn: return "Dreamborn.ink"
            case .lorcanaHQ: return "Lorcana HQ"
            }
        }
    }

    // MARK: - Main Import Methods

    func importFromText(_ text: String, format: ImportFormat = .textList, progressCallback: ((Double) -> Void)? = nil) async -> ImportResult {
        print("📥 [Import] Starting import - Format: \(format.description)")
        print("📄 [Import] Text length: \(text.count) characters")

        var successful: [ImportedCard] = []
        var failed: [FailedImport] = []
        var duplicates: [ImportedCard] = []

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        print("📊 [Import] Processing \(lines.count) lines")

        for (index, line) in lines.enumerated() {
            // Update progress every 10 lines or on last line
            if index % 10 == 0 || index == lines.count - 1 {
                let progress = Double(index + 1) / Double(lines.count)
                await MainActor.run {
                    progressCallback?(progress)
                }
            }

            // Skip header lines - check for common CSV headers
            if index == 0 {
                let lowerLine = line.lowercased()
                // Dreamborn header: "Normal,Foil,Name,Set,Card Number,Color,Rarity,Price,Foil Price"
                if lowerLine.contains("normal") && lowerLine.contains("foil") && lowerLine.contains("name") {
                    print("⏭️  [Import] Skipping Dreamborn header")
                    continue
                }
                // Other headers
                if lowerLine.contains("name") || lowerLine.contains("card") {
                    print("⏭️  [Import] Skipping header: \(line)")
                    continue
                }
            }

            // Special handling for Dreamborn format to process both normal and foil quantities
            if format == .dreamborn {
                // parseDreambornLineRaw returns nil for rows with 0,0 quantities
                if let (normalQty, foilQty, cardName, setName) = parseDreambornLineRaw(line) {
                    print("📦 [Import] Processing line \(index + 1): Normal=\(normalQty), Foil=\(foilQty), Name='\(cardName)'")
                    var lineHadSuccess = false
                    var lineHadFailure = false
                    var failureReasons: [String] = []

                    // Process normal quantity
                    if normalQty > 0 {
                        print("🔍 [Import] Line \(index + 1): '\(cardName)' x\(normalQty) from \(setName ?? "any") [Normal]")
                        if let matchedCard = findCard(name: cardName, setName: setName, variant: .normal) {
                            successful.append(ImportedCard(card: matchedCard, quantity: normalQty, originalLine: line))
                            print("✅ [Import] Matched: \(matchedCard.name) [Normal]")
                            lineHadSuccess = true
                        } else {
                            let setInfo = setName != nil ? " from set '\(setName!)'" : ""
                            failureReasons.append("Normal: Card not found '\(cardName)'\(setInfo)")
                            print("❌ [Import] Failed: \(cardName)\(setInfo) [Normal]")
                            lineHadFailure = true
                        }
                    }

                    // Process foil quantity
                    if foilQty > 0 {
                        print("🔍 [Import] Line \(index + 1): '\(cardName)' x\(foilQty) from \(setName ?? "any") [Foil]")

                        // Try to find foil variant first
                        if let matchedCard = findCard(name: cardName, setName: setName, variant: .foil) {
                            successful.append(ImportedCard(card: matchedCard, quantity: foilQty, originalLine: line))
                            print("✅ [Import] Matched: \(matchedCard.name) [Foil]")
                            lineHadSuccess = true
                        }
                        // If foil not found, try to find normal variant and create foil version
                        else if let normalCard = findCard(name: cardName, setName: setName, variant: .normal) {
                            // Create a foil version of the normal card
                            let foilCard = createFoilVariant(from: normalCard)
                            successful.append(ImportedCard(card: foilCard, quantity: foilQty, originalLine: line))
                            print("✅ [Import] Created foil variant from normal: \(foilCard.name) [Foil]")
                            lineHadSuccess = true
                        }
                        else {
                            let setInfo = setName != nil ? " from set '\(setName!)'" : ""
                            failureReasons.append("Foil: Card not found '\(cardName)'\(setInfo)")
                            print("❌ [Import] Failed: \(cardName)\(setInfo) [Foil]")
                            lineHadFailure = true
                        }
                    }

                    // Only add to failed if the ENTIRE line failed (no successes)
                    if lineHadFailure && !lineHadSuccess {
                        failed.append(FailedImport(originalLine: line, reason: failureReasons.joined(separator: "; ")))
                    }
                }
            } else {
                // Standard parsing for other formats
                let parsed = parseLine(line, format: format)

                if let (cardName, setName, variant, quantity) = parsed {
                    print("🔍 [Import] Line \(index + 1): '\(cardName)' x\(quantity) from \(setName ?? "any") [\(variant.displayName)]")

                    if let matchedCard = findCard(name: cardName, setName: setName, variant: variant) {
                        let importedCard = ImportedCard(
                            card: matchedCard,
                            quantity: quantity,
                            originalLine: line
                        )
                        successful.append(importedCard)
                        print("✅ [Import] Matched: \(matchedCard.name)")
                    } else {
                        let setInfo = setName != nil ? " from set '\(setName!)'" : ""
                        let failedImport = FailedImport(
                            originalLine: line,
                            reason: "Card not found: '\(cardName)'\(setInfo) [\(variant.displayName)]"
                        )
                        failed.append(failedImport)
                        print("❌ [Import] Failed: \(cardName)\(setInfo) [\(variant.displayName)]")
                    }
                }
            }
        }

        print("📊 [Import] Complete - Success: \(successful.count), Failed: \(failed.count)")

        return ImportResult(
            successful: successful,
            failed: failed,
            duplicates: duplicates
        )
    }

    // MARK: - Line Parsing

    private func parseLine(_ line: String, format: ImportFormat) -> (name: String, set: String?, variant: CardVariant, quantity: Int)? {
        switch format {
        case .csv:
            return parseCSVLine(line)
        case .textList:
            return parseTextListLine(line)
        case .dreamborn:
            return parseDreambornLine(line)
        case .lorcanaHQ:
            return parseLorcanaHQLine(line)
        }
    }

    // CSV format: "Card Name","Set Name","Variant","Quantity"
    // or: "Card Name, Set Name, Quantity"
    private func parseCSVLine(_ line: String) -> (name: String, set: String?, variant: CardVariant, quantity: Int)? {
        // Handle both quoted and unquoted CSV
        var components: [String] = []

        if line.contains("\"") {
            // Parse quoted CSV
            let regex = try? NSRegularExpression(pattern: "\"([^\"]*)\"|([^,]+)", options: [])
            let nsLine = line as NSString
            let matches = regex?.matches(in: line, options: [], range: NSRange(location: 0, length: nsLine.length))

            components = matches?.compactMap { match in
                let range1 = match.range(at: 1)
                let range2 = match.range(at: 2)

                if range1.location != NSNotFound {
                    return nsLine.substring(with: range1).trimmingCharacters(in: .whitespaces)
                } else if range2.location != NSNotFound {
                    return nsLine.substring(with: range2).trimmingCharacters(in: .whitespaces)
                }
                return nil
            }.filter { !$0.isEmpty } ?? []
        } else {
            // Simple comma split
            components = line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }

        guard !components.isEmpty else { return nil }

        let cardName = components[0]
        var setName: String? = components.count > 1 ? components[1] : nil
        var quantity = 1
        var variant = CardVariant.normal

        // Parse quantity from last component if it's a number
        if let lastComponent = components.last,
           let parsedQuantity = Int(lastComponent) {
            quantity = parsedQuantity

            // If we have 4 components: name, set, variant, quantity
            if components.count == 4 {
                variant = parseVariant(components[2])
            } else if components.count == 3 {
                // Could be: name, set, quantity OR name, variant, quantity
                // Check if second component looks like a set name
                if components[1].lowercased().contains("chapter") ||
                   components[1].lowercased().contains("floodborn") ||
                   components[1].lowercased().contains("inklands") {
                    setName = components[1]
                } else {
                    variant = parseVariant(components[1])
                    setName = nil
                }
            }
        } else if components.count >= 2 {
            // Last component isn't a number, might be variant
            variant = parseVariant(components.last!)
        }

        return (cardName, setName, variant, quantity)
    }

    // Text list format:
    // "1x Card Name" or "Card Name x1" or "2 Card Name" or just "Card Name"
    private func parseTextListLine(_ line: String) -> (name: String, set: String?, variant: CardVariant, quantity: Int)? {
        var quantity = 1
        var cardName = line
        var variant = CardVariant.normal

        // Pattern: "2x Card Name" or "x2 Card Name"
        if let match = line.range(of: #"^(\d+)[x×]\s*(.+)$"#, options: .regularExpression) {
            let components = line.components(separatedBy: CharacterSet(charactersIn: "x×"))
            if let qty = Int(components[0].trimmingCharacters(in: .whitespaces)) {
                quantity = qty
                cardName = components[1].trimmingCharacters(in: .whitespaces)
            }
        }
        // Pattern: "Card Name x2" or "Card Name ×2"
        else if let match = line.range(of: #"^(.+?)[x×]\s*(\d+)$"#, options: .regularExpression) {
            let components = line.components(separatedBy: CharacterSet(charactersIn: "x×"))
            cardName = components[0].trimmingCharacters(in: .whitespaces)
            if let qty = Int(components[1].trimmingCharacters(in: .whitespaces)) {
                quantity = qty
            }
        }
        // Pattern: "2 Card Name"
        else if let match = line.range(of: #"^(\d+)\s+(.+)$"#, options: .regularExpression) {
            let components = line.split(separator: " ", maxSplits: 1)
            if let qty = Int(components[0]) {
                quantity = qty
                cardName = String(components[1])
            }
        }

        // Check for variant keywords
        let lowerName = cardName.lowercased()
        if lowerName.contains("foil") {
            variant = .foil
            cardName = cardName.replacingOccurrences(of: "(Foil)", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Foil", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
        } else if lowerName.contains("enchanted") {
            variant = .enchanted
            cardName = cardName.replacingOccurrences(of: "(Enchanted)", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Enchanted", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
        }

        return (cardName, nil, variant, quantity)
    }

    // Dreamborn format parser that returns both normal and foil quantities
    private func parseDreambornLineRaw(_ line: String) -> (normalQty: Int, foilQty: Int, name: String, set: String?)? {
        // Parse CSV properly, handling quoted fields and preserving empty fields
        var components: [String] = []

        var currentField = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                components.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        // Add the last field
        components.append(currentField.trimmingCharacters(in: .whitespaces))

        // Dreamborn format: Normal,Foil,Name,Set,Card Number,Color,Rarity,Price,Foil Price
        // Index:            0      1    2    3    4           5      6       7      8
        guard components.count >= 4 else {
            print("⚠️ [Parse] Dreamborn parse failed - only \(components.count) components in line")
            return nil
        }

        let normalQty = Int(components[0]) ?? 0
        let foilQty = Int(components[1]) ?? 0
        let cardName = components[2]

        // Skip cards with 0 quantity in both columns
        guard normalQty > 0 || foilQty > 0 else { return nil }

        // Get set name from index 3 if available
        var setName: String? = nil
        if components.count > 3 && !components[3].isEmpty {
            let setNumber = components[3]
            setName = mapDreambornSetNumber(setNumber)
        }

        return (normalQty, foilQty, cardName, setName)
    }

    // Dreamborn format: CSV with columns: Normal,Foil,Name,Set,Card Number,Color,Rarity,Price,Foil Price
    // NOTE: This is kept for compatibility but shouldn't be used for Dreamborn imports
    private func parseDreambornLine(_ line: String) -> (name: String, set: String?, variant: CardVariant, quantity: Int)? {
        // Parse quoted CSV
        var components: [String] = []

        // Parse CSV properly, handling quoted fields and preserving empty fields
        var currentField = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                components.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        // Add the last field
        components.append(currentField.trimmingCharacters(in: .whitespaces))

        // Dreamborn format: Normal,Foil,Name,Set,Card Number,Color,Rarity,Price,Foil Price
        // Index:            0      1    2    3    4           5      6       7      8
        guard components.count >= 4 else { return nil }

        let normalQty = Int(components[0]) ?? 0
        let foilQty = Int(components[1]) ?? 0
        let cardName = components[2]

        // Skip cards with 0 quantity in both columns
        guard normalQty > 0 || foilQty > 0 else { return nil }

        // Get set name from index 3 if available
        var setName: String? = nil
        if components.count > 3 && !components[3].isEmpty {
            let setNumber = components[3]
            setName = mapDreambornSetNumber(setNumber)
        }

        // Return normal variant with normal quantity (foils will be handled separately)
        // For now, we only import the normal quantity. If user has foils, they'll need to manually adjust
        let variant: CardVariant = foilQty > 0 && normalQty == 0 ? .foil : .normal
        let quantity = variant == .foil ? foilQty : normalQty

        return (cardName, setName, variant, quantity)
    }

    // Map Dreamborn set numbers to full set names
    private func mapDreambornSetNumber(_ setNum: String) -> String? {
        // Dreamborn uses numbers like "001", "002", "003", "004", "005", "006"
        // Map to set names
        switch setNum {
        case "001", "1": return "The First Chapter"
        case "002", "2": return "Rise of the Floodborn"
        case "003", "3": return "Into the Inklands"
        case "004", "4": return "Ursula's Return"
        case "005", "5": return "Shimmering Skies"
        case "006", "6": return "Azurite Sea"
        case "007", "7": return "Archazia's Island"
        case "P1": return "Promo" // Promo cards
        case "C1": return "Promo" // Convention promos
        case "D23": return "Promo" // D23 promos
        default: return nil
        }
    }

    // Lorcana HQ format
    private func parseLorcanaHQLine(_ line: String) -> (name: String, set: String?, variant: CardVariant, quantity: Int)? {
        return parseTextListLine(line)
    }

    // MARK: - Card Matching

    private func createFoilVariant(from normalCard: LorcanaCard) -> LorcanaCard {
        // Create a new card with foil variant but same other properties
        return LorcanaCard(
            id: normalCard.id.replacingOccurrences(of: "_N_", with: "_F_"),
            name: normalCard.name,
            cost: normalCard.cost,
            type: normalCard.type,
            rarity: normalCard.rarity,
            setName: normalCard.setName,
            cardText: normalCard.cardText,
            imageUrl: normalCard.imageUrl,
            price: normalCard.price,
            variant: .foil,  // Change to foil
            cardNumber: normalCard.cardNumber,
            uniqueId: normalCard.uniqueId,
            inkwell: normalCard.inkwell,
            strength: normalCard.strength,
            willpower: normalCard.willpower,
            lore: normalCard.lore,
            franchise: normalCard.franchise,
            inkColor: normalCard.inkColor
        )
    }

    private func findCard(name: String, setName: String?, variant: CardVariant) -> LorcanaCard? {
        let allCards = dataManager.getAllCards()

        let normalizedName = normalizeName(name)

        // Priority 1: Exact match (name + set + variant)
        if let set = setName {
            let normalizedSet = normalizeSetName(set)

            print("🔎 [Match] Looking for '\(normalizedName)' in set '\(normalizedSet)' with variant \(variant.rawValue)")

            if let exactMatch = allCards.first(where: {
                normalizeName($0.name) == normalizedName &&
                normalizeSetName($0.setName) == normalizedSet &&
                $0.variant == variant
            }) {
                print("✅ [Match] Exact match found: \(exactMatch.name) from \(exactMatch.setName)")
                return exactMatch
            }

            print("⚠️ [Match] No exact match in set '\(normalizedSet)', trying other sets...")

            // If set was provided but no exact match, try without set constraint
            // but prefer matches with the correct variant
            if let fallbackMatch = allCards.first(where: {
                normalizeName($0.name) == normalizedName &&
                $0.variant == variant
            }) {
                print("⚠️ [Match] Fallback match found: \(fallbackMatch.name) from \(fallbackMatch.setName) (wanted \(set))")
                return fallbackMatch
            }
        }

        // Priority 2: Exact name + variant (any set) - only if no set was specified
        if let match = allCards.first(where: {
            normalizeName($0.name) == normalizedName &&
            $0.variant == variant
        }) {
            return match
        }

        // Priority 3: Fuzzy match on name (any variant, any set)
        let fuzzyMatches = allCards.filter { card in
            let cardName = normalizeName(card.name)
            return cardName.contains(normalizedName) || normalizedName.contains(cardName)
        }

        if let bestMatch = fuzzyMatches.first(where: { $0.variant == variant }) {
            return bestMatch
        }

        // Priority 4: Return any fuzzy match
        return fuzzyMatches.first
    }

    // MARK: - Helper Methods

    private func normalizeName(_ name: String) -> String {
        return name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // Normalize special spaces
            .replacingOccurrences(of: "\u{00A0}", with: " ")  // Non-breaking space → regular space
            .replacingOccurrences(of: "  ", with: " ")
            // Normalize different types of apostrophes and quotes
            .replacingOccurrences(of: "’", with: "'")  // Right single quote → regular apostrophe
            .replacingOccurrences(of: "‘", with: "'")  // Left single quote → regular apostrophe
            .replacingOccurrences(of: "ʼ", with: "'")  // Modifier letter apostrophe → regular apostrophe
            .replacingOccurrences(of: "“", with: "\"") // Left double quote → regular quote
            .replacingOccurrences(of: "”", with: "\"") // Right double quote → regular quote
            .replacingOccurrences(of: "„", with: "\"") // Low double quote → regular quote
            // Normalize multiple dots/ellipsis
            .replacingOccurrences(of: "…", with: "...")  // Ellipsis character → three dots
            .replacingOccurrences(of: "......", with: "...") // Multiple dots → three dots
            .replacingOccurrences(of: ".....", with: "...")
            .replacingOccurrences(of: "....", with: "...")
            // Normalize dots with spaces to just dots (for "has set my heaaaaaaart . . ." → "...")
            .replacingOccurrences(of: " . . . ", with: " ... ")
            .replacingOccurrences(of: " . . .", with: " ...")
            .replacingOccurrences(of: ". . .", with: "...")
            .replacingOccurrences(of: " .  . ", with: " ... ")
            .replacingOccurrences(of: " .  .", with: " ...")
            .replacingOccurrences(of: ".  .", with: "...")
            // Normalize dashes
            .replacingOccurrences(of: "–", with: "-")  // En dash → regular dash
            .replacingOccurrences(of: "—", with: "-")  // Em dash → regular dash
    }

    private func normalizeSetName(_ setName: String) -> String {
        let normalized = setName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Map common abbreviations
        let abbreviations: [String: String] = [
            "tfc": "the first chapter",
            "rotf": "rise of the floodborn",
            "iti": "into the inklands",
            "urs": "ursula's return",
            "ssk": "shimmering skies",
            "as": "azurite sea"
        ]

        return abbreviations[normalized] ?? normalized
    }

    private func parseVariant(_ string: String) -> CardVariant {
        let lower = string.lowercased().trimmingCharacters(in: .whitespaces)

        if lower.contains("foil") {
            return .foil
        } else if lower.contains("enchanted") {
            return .enchanted
        } else if lower.contains("promo") {
            return .promo
        } else if lower.contains("normal") || lower.contains("standard") {
            return .normal
        }

        return .normal
    }

    // MARK: - Export (for future use)

    func exportToCSV(cards: [LorcanaCard]) -> String {
        var csv = "Card Name,Set Name,Variant,Quantity\n"

        // Group cards by name+set+variant and count quantities
        var cardGroups: [String: (card: LorcanaCard, quantity: Int)] = [:]

        for card in cards {
            let key = "\(card.name)|\(card.setName)|\(card.variant.rawValue)"
            if let existing = cardGroups[key] {
                cardGroups[key] = (card, existing.quantity + 1)
            } else {
                cardGroups[key] = (card, 1)
            }
        }

        for (_, group) in cardGroups {
            let name = group.card.name.replacingOccurrences(of: "\"", with: "\"\"")
            let set = group.card.setName.replacingOccurrences(of: "\"", with: "\"\"")
            let variant = group.card.variant.displayName
            csv += "\"\(name)\",\"\(set)\",\"\(variant)\",\(group.quantity)\n"
        }

        return csv
    }
}

