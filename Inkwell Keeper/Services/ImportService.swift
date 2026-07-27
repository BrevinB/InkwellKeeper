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
        case collectr         // Collectr export (header-mapped CSV)
        case officialBackup   // Official Lorcana app backup (JSON)

        var description: String {
            switch self {
            case .csv: return "CSV File"
            case .textList: return "Text List"
            case .dreamborn: return "Dreamborn.ink"
            case .lorcanaHQ: return "Lorcana HQ"
            case .collectr: return "Collectr"
            case .officialBackup: return "Official App Backup"
            }
        }
    }

    /// True when the text looks like a collection backup from the official
    /// Disney Lorcana app (a JSON document, not a line-based CSV).
    static func isOfficialBackup(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{") && trimmed.contains("\"OwnedCardQuantitiesV2\"")
    }

    enum OfficialBackupError: LocalizedError {
        case invalidLink
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .invalidLink:
                return "That doesn't look like a Lorcana backup link. In the official app, use Collection backup → Backup now, then copy the link it creates."
            case .downloadFailed:
                return "Couldn't download the backup. Check your connection, or create a fresh backup link in the official app and try again."
            }
        }
    }

    /// The official app's "Backup now" produces a share link that deep-links back
    /// into the app, but its `id` parameter addresses the raw backup JSON hosted at
    /// Ravensburger's sharing endpoint. Accepts the share link, the direct backup
    /// URL, or a bare backup id.
    static func officialBackupDownloadURL(from shareLink: String) -> URL? {
        let trimmed = shareLink.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed) {
            if url.host()?.hasSuffix("sharing.lorcana.ravensburger.com") == true,
               url.path.hasPrefix("/backup/") {
                return url
            }
            if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "id" })?.value,
               UUID(uuidString: id) != nil {
                return URL(string: "https://sharing.lorcana.ravensburger.com/backup/\(id).json")
            }
        }

        if UUID(uuidString: trimmed) != nil {
            return URL(string: "https://sharing.lorcana.ravensburger.com/backup/\(trimmed).json")
        }

        return nil
    }

    /// Download the backup JSON behind an official-app backup share link.
    func fetchOfficialBackup(fromShareLink link: String) async throws -> String {
        guard let url = Self.officialBackupDownloadURL(from: link) else {
            throw OfficialBackupError.invalidLink
        }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8),
              Self.isOfficialBackup(text) else {
            throw OfficialBackupError.downloadFailed
        }

        return text
    }

    /// Column positions discovered from a CSV header row. Collectr (and similar apps)
    /// export with named columns whose order isn't guaranteed, so we map by header
    /// name instead of position.
    struct HeaderColumnMap {
        var name: Int?
        var set: Int?
        var cardNumber: Int?
        var variant: Int?
        var quantity: Int?
        /// "Category"/"Game" column — used to skip non-Lorcana rows in multi-game exports.
        var game: Int?
        /// Dual-count exports (Lorcana.gg: "Normal,Foil,Name,Set,Number") carry separate
        /// per-variant count columns instead of a variant + quantity pair.
        var normalCount: Int?
        var foilCount: Int?

        init?(headerLine: String) {
            let headers = ImportService.shared.parseCSVFields(headerLine).map { $0.lowercased() }

            let nameAliases = ["product name", "card name", "name", "product", "card"]
            let setAliases = ["set name", "set", "expansion", "series"]
            let numberAliases = ["card number", "collector number", "card no", "card #", "number", "no.", "#"]
            let variantAliases = ["variance", "variant", "printing", "finish", "foil", "holofoil"]
            let quantityAliases = ["quantity", "count", "qty", "amount"]
            let gameAliases = ["category", "game", "tcg", "product line"]

            // Bare "Normal" + "Foil" headers together mean per-variant count columns,
            // so "foil" must not be claimed as a variant column below.
            let hasDualCounts = headers.contains("normal") && headers.contains("foil")

            for (index, header) in headers.enumerated() {
                if hasDualCounts, header == "normal" {
                    normalCount = index
                } else if hasDualCounts, header == "foil" {
                    foilCount = index
                } else if name == nil, nameAliases.contains(header) {
                    name = index
                } else if set == nil, setAliases.contains(header) {
                    set = index
                } else if cardNumber == nil, numberAliases.contains(header) {
                    cardNumber = index
                } else if variant == nil, variantAliases.contains(header) {
                    variant = index
                } else if quantity == nil, quantityAliases.contains(header) {
                    quantity = index
                } else if game == nil, gameAliases.contains(header) {
                    game = index
                }
            }

            guard name != nil else { return nil }
        }
    }

    // MARK: - Main Import Methods

    /// Live stats reported during import
    struct ImportProgress {
        var progress: Double = 0
        var totalCards: Int = 0
        var uniqueCards: Int = 0
        var normalCards: Int = 0
        var foilCards: Int = 0
        var failedCards: Int = 0
    }

    /// The card database loads asynchronously at launch. An import started
    /// before it finishes (the fresh-install flow: open app, import collection)
    /// would match against an empty catalog and fail every row — wait for it.
    private func waitForCardDatabase() async {
        var attempts = 0
        while dataManager.getAllCards().isEmpty && attempts < 60 {
            try? await Task.sleep(for: .milliseconds(500))
            attempts += 1
        }
    }

    /// Process and import in a single pass — calls `onCardMatched` for each successfully matched card
    /// so the caller can add it to the collection immediately without a second pass.
    func importAndAdd(
        _ text: String,
        format: ImportFormat = .textList,
        onCardMatched: @MainActor (LorcanaCard, Int) -> Void,
        progressCallback: ((ImportProgress) -> Void)? = nil
    ) async -> ImportResult {
        var successful: [ImportedCard] = []
        var failed: [FailedImport] = []
        var stats = ImportProgress()
        await waitForCardDatabase()
        let cardIndex = CardIndex(cards: dataManager.getAllCards())

        if format == .officialBackup {
            let result = matchOfficialBackup(text, cardIndex: cardIndex)
            for item in result.successful {
                stats.totalCards += item.quantity
                stats.uniqueCards += 1
                if item.card.variant == .foil {
                    stats.foilCards += item.quantity
                } else {
                    stats.normalCards += item.quantity
                }
                await MainActor.run {
                    onCardMatched(item.card, item.quantity)
                }
            }
            stats.failedCards = result.failed.count
            stats.progress = 1.0
            await MainActor.run {
                progressCallback?(stats)
            }
            return result
        }

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let columnMap = format == .collectr ? lines.first.flatMap(HeaderColumnMap.init) : nil

        for (index, line) in lines.enumerated() {
            // Skip header
            if index == 0 {
                if columnMap != nil { continue }
                let lowerLine = line.lowercased()
                if lowerLine.contains("set number") && lowerLine.contains("variant") { continue }
                if lowerLine.contains("name") && (lowerLine.contains("card") || lowerLine.contains("normal") || lowerLine.contains("rarity")) { continue }
            }

            let matched = matchLine(line, format: format, cardIndex: cardIndex, columnMap: columnMap)

            for card in matched.cards {
                successful.append(card)
                stats.totalCards += card.quantity
                stats.uniqueCards += 1
                if card.card.variant == .foil {
                    stats.foilCards += card.quantity
                } else {
                    stats.normalCards += card.quantity
                }
                await MainActor.run {
                    onCardMatched(card.card, card.quantity)
                }
            }
            for fail in matched.failures {
                failed.append(fail)
                stats.failedCards += 1
            }

            // Update progress
            if index % 10 == 0 || index == lines.count - 1 {
                stats.progress = Double(index + 1) / Double(lines.count)
                await MainActor.run {
                    progressCallback?(stats)
                }
            }
        }

        return ImportResult(successful: successful, failed: failed, duplicates: [])
    }

    /// Match a single line, returning matched cards and any failures
    private func matchLine(_ line: String, format: ImportFormat, cardIndex: CardIndex, columnMap: HeaderColumnMap? = nil) -> (cards: [ImportedCard], failures: [FailedImport]) {
        var cards: [ImportedCard] = []
        var failures: [FailedImport] = []

        if format == .collectr {
            guard let columnMap else { return (cards, failures) }

            for parsed in parseHeaderMappedRows(line, columnMap: columnMap) {
                if let setName = parsed.set, let number = parsed.cardNumber,
                   let matchedCard = matchBySetAndNumber(setName: setName, number: number, csvVariant: parsed.variant, cardIndex: cardIndex) {
                    cards.append(ImportedCard(card: matchedCard, quantity: parsed.quantity, originalLine: line))
                } else if parsed.variant == .foil,
                          let baseCard = findCard(name: parsed.name, setName: parsed.set, variant: .normal, cardIndex: cardIndex) {
                    let foilCard = baseCard.variant == .normal ? createFoilVariant(from: baseCard) : baseCard
                    cards.append(ImportedCard(card: foilCard, quantity: parsed.quantity, originalLine: line))
                } else if let matchedCard = findCard(name: parsed.name, setName: parsed.set, variant: parsed.variant, cardIndex: cardIndex) {
                    cards.append(ImportedCard(card: matchedCard, quantity: parsed.quantity, originalLine: line))
                } else {
                    let setInfo = parsed.set != nil ? " from set '\(parsed.set!)'" : ""
                    failures.append(FailedImport(originalLine: line, reason: "Card not found: '\(parsed.name)'\(setInfo)"))
                }
            }
            return (cards, failures)
        }

        if format == .dreamborn {
            if let parsed = parseDreambornLine(line) {
                let (cardName, setName, variant, quantity) = (parsed.name, parsed.set, parsed.variant, parsed.quantity)

                // Priority 0: set + card number is unambiguous, and is the only way to
                // match Epic/Enchanted/Iconic printings, which share a name with their
                // base card but live at card numbers above the set's main run.
                if let setName, let number = parsed.cardNumber,
                   let matchedCard = matchBySetAndNumber(setName: setName, number: number, csvVariant: variant, cardIndex: cardIndex) {
                    cards.append(ImportedCard(card: matchedCard, quantity: quantity, originalLine: line))
                    return (cards, failures)
                }

                // Nameless rows (4-column exports) have nothing to fall back on —
                // report the miss instead of skipping the line silently.
                if cardName.isEmpty {
                    failures.append(FailedImport(originalLine: line, reason: "Card not found by set and number: '\(line)'"))
                    return (cards, failures)
                }

                if variant == .foil {
                    if let matchedCard = findCard(name: cardName, setName: setName, variant: .foil, cardIndex: cardIndex),
                       matchedCard.variant == .foil {
                        cards.append(ImportedCard(card: matchedCard, quantity: quantity, originalLine: line))
                    } else if let baseCard = findCard(name: cardName, setName: setName, variant: .normal, cardIndex: cardIndex) {
                        let foilCard = baseCard.variant == .normal ? createFoilVariant(from: baseCard) : baseCard
                        cards.append(ImportedCard(card: foilCard, quantity: quantity, originalLine: line))
                    } else {
                        let setInfo = setName != nil ? " from set '\(setName!)'" : ""
                        failures.append(FailedImport(originalLine: line, reason: "Foil card not found: '\(cardName)'\(setInfo)"))
                    }
                } else {
                    if let matchedCard = findCard(name: cardName, setName: setName, variant: variant, cardIndex: cardIndex) {
                        cards.append(ImportedCard(card: matchedCard, quantity: quantity, originalLine: line))
                    } else {
                        let setInfo = setName != nil ? " from set '\(setName!)'" : ""
                        failures.append(FailedImport(originalLine: line, reason: "Card not found: '\(cardName)'\(setInfo)"))
                    }
                }
            }
        } else if let (cardName, setName, variant, quantity) = parseLine(line, format: format) {
            if let matchedCard = findCard(name: cardName, setName: setName, variant: variant, cardIndex: cardIndex) {
                cards.append(ImportedCard(card: matchedCard, quantity: quantity, originalLine: line))
            } else {
                let setInfo = setName != nil ? " from set '\(setName!)'" : ""
                failures.append(FailedImport(originalLine: line, reason: "Card not found: '\(cardName)'\(setInfo) [\(variant.displayName)]"))
            }
        }

        return (cards, failures)
    }

    /// Match a Dreamborn row by set + card number. Returns nil if the number isn't in
    /// the local database (promo sets, letter-suffixed reprints), so callers can fall
    /// back to name-based matching.
    private func matchBySetAndNumber(setName: String, number: Int, csvVariant: CardVariant, cardIndex: CardIndex) -> LorcanaCard? {
        let candidates = cardIndex.cards(setName: normalizeSetName(setName), number: number)
        guard !candidates.isEmpty else { return nil }

        if let exact = candidates.first(where: { $0.variant == csvVariant }) {
            return exact
        }

        if csvVariant != .normal {
            // Special printings (Epic/Enchanted/Iconic/Promo) only exist foiled —
            // exports mark them "foil", so import them as the printing itself.
            if let special = candidates.first(where: { $0.variant != .normal }) {
                return special
            }
            if csvVariant == .foil {
                return createFoilVariant(from: candidates[0])
            }
        }

        return candidates.first(where: { $0.variant == .normal }) ?? candidates[0]
    }

    func importFromText(_ text: String, format: ImportFormat = .textList, progressCallback: ((Double) -> Void)? = nil) async -> ImportResult {
        var successful: [ImportedCard] = []
        var failed: [FailedImport] = []
        await waitForCardDatabase()
        let cardIndex = CardIndex(cards: dataManager.getAllCards())

        if format == .officialBackup {
            let result = matchOfficialBackup(text, cardIndex: cardIndex)
            await MainActor.run {
                progressCallback?(1.0)
            }
            return result
        }

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let columnMap = format == .collectr ? lines.first.flatMap(HeaderColumnMap.init) : nil

        for (index, line) in lines.enumerated() {
            // Update progress every 10 lines or on last line
            if index % 10 == 0 || index == lines.count - 1 {
                let progress = Double(index + 1) / Double(lines.count)
                await MainActor.run {
                    progressCallback?(progress)
                }
            }

            // Skip header lines
            if index == 0 {
                if columnMap != nil { continue }
                let lowerLine = line.lowercased()
                // Dreamborn header: "Set Number,Card Number,Variant,Count,Name,Color,Rarity"
                if lowerLine.contains("set number") && lowerLine.contains("variant") {
                    continue
                }
                // Other CSV headers
                if lowerLine.contains("name") && (lowerLine.contains("card") || lowerLine.contains("normal") || lowerLine.contains("rarity")) {
                    continue
                }
            }

            let matched = matchLine(line, format: format, cardIndex: cardIndex, columnMap: columnMap)
            successful.append(contentsOf: matched.cards)
            failed.append(contentsOf: matched.failures)
        }

        return ImportResult(
            successful: successful,
            failed: failed,
            duplicates: []
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
            guard let parsed = parseDreambornLine(line) else { return nil }
            return (parsed.name, parsed.set, parsed.variant, parsed.quantity)
        case .lorcanaHQ:
            return parseLorcanaHQLine(line)
        case .collectr:
            // Collectr rows need the header column map — handled directly in matchLine
            return nil
        case .officialBackup:
            // JSON documents aren't line-based — handled before the line loop
            return nil
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

    // Dreamborn CSV format:
    // Set Number,Card Number,Variant,Count,Name,Color,Rarity
    // 001,1,normal,2,"Ariel - On Human Legs",Amber,Uncommon
    // 001,4,foil,1,"Goofy - Musketeer",Amber,Uncommon
    //
    // Each row is a single variant (normal or foil) with its own count.
    // Card Number can include letter suffixes for reprints (e.g., "4a", "4b").
    func parseDreambornLine(_ line: String) -> (name: String, set: String?, variant: CardVariant, quantity: Int, cardNumber: Int?)? {
        let components = parseCSVFields(line)

        // Current format: Set Number(0), Card Number(1), Variant(2), Count(3), Name(4), Color(5), Rarity(6)
        // Inklore.gg / LorcanaExporter also emit a nameless 4-column variant:
        // Set Number(0), Card Number(1), Variant(2), Count(3)
        guard components.count >= 4 else { return nil }

        let setNumber = components[0]
        let variantString = components[2].lowercased()
        let quantity = Int(components[3]) ?? 0

        // Dreamborn exports don't quote names, so a name containing commas
        // ("Fix-It Felix, Jr. - Trusty Builder") spills across extra fields.
        // Name is everything between Count and the trailing Color + Rarity columns.
        let cardName: String
        if components.count == 4 {
            // Nameless rows only carry set + number — require a plausible variant
            // so arbitrary 4-field CSV lines don't slip through as cards.
            guard variantString == "normal" || variantString == "foil" else { return nil }
            cardName = ""
        } else if components.count > 7 {
            cardName = components[4...(components.count - 3)].joined(separator: ", ")
        } else {
            cardName = components[4]
        }

        guard quantity > 0, components.count == 4 || !cardName.isEmpty else { return nil }

        let variant: CardVariant = variantString == "foil" ? .foil : .normal
        let setName = mapDreambornSetNumber(setNumber)
        // Letter-suffixed reprints ("4a") don't parse — those fall back to name matching
        let cardNumber = Int(components[1])

        return (cardName, setName, variant, quantity, cardNumber)
    }

    /// Parse a row of a header-mapped CSV export (Collectr, Lorcana.gg, and similar).
    /// Dual-count rows (separate Normal/Foil columns) can produce two entries.
    /// Returns an empty array for rows that should be skipped silently
    /// (non-Lorcana games, zero quantities, missing name).
    func parseHeaderMappedRows(_ line: String, columnMap: HeaderColumnMap) -> [(name: String, set: String?, variant: CardVariant, quantity: Int, cardNumber: Int?)] {
        let fields = parseCSVFields(line)

        func field(_ index: Int?) -> String? {
            guard let index, index < fields.count else { return nil }
            let value = fields[index]
            return value.isEmpty ? nil : value
        }

        // Multi-game portfolios export every TCG into one file — skip other games
        // rather than reporting each of their cards as a failed match.
        if let game = field(columnMap.game), !game.localizedStandardContains("lorcana") {
            return []
        }

        guard var name = field(columnMap.name) else { return [] }

        var variant = parseVariant(field(columnMap.variant) ?? "")

        // Some exports tag the printing onto the name instead: "Elsa - Snow Queen (Enchanted)"
        if let range = name.range(of: #"\s*\((foil|holofoil|cold foil|enchanted|epic|iconic)\)\s*$"#, options: [.regularExpression, .caseInsensitive]) {
            if variant == .normal {
                variant = parseVariant(String(name[range]))
            }
            name.removeSubrange(range)
        }

        var setName = field(columnMap.set)
        // Collectr prefixes the game onto set names ("Disney Lorcana: The First Chapter")
        if let set = setName, let colon = set.firstIndex(of: ":"), set[..<colon].localizedStandardContains("lorcana") {
            setName = String(set[set.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        // Lorcana.gg writes set codes ("001") rather than set names
        if let set = setName, let mapped = mapDreambornSetNumber(set) {
            setName = mapped
        }

        // Card numbers may be "207/204" style — the number before the slash is the card's
        let cardNumber = field(columnMap.cardNumber)
            .map { $0.split(separator: "/").first.map(String.init) ?? $0 }
            .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        // Dual-count exports: one row can carry both a normal and a foil quantity
        if columnMap.normalCount != nil || columnMap.foilCount != nil {
            var rows: [(name: String, set: String?, variant: CardVariant, quantity: Int, cardNumber: Int?)] = []
            if let normalQty = field(columnMap.normalCount).flatMap(Int.init), normalQty > 0 {
                rows.append((name, setName, .normal, normalQty, cardNumber))
            }
            if let foilQty = field(columnMap.foilCount).flatMap(Int.init), foilQty > 0 {
                rows.append((name, setName, .foil, foilQty, cardNumber))
            }
            return rows
        }

        let quantity = field(columnMap.quantity).flatMap(Int.init) ?? 1
        guard quantity > 0 else { return [] }

        return [(name, setName, variant, quantity, cardNumber)]
    }

    // MARK: - Official App Backup (JSON)

    private struct OfficialBackup: Decodable {
        let ownedCardQuantities: [Entry]

        enum CodingKeys: String, CodingKey {
            case ownedCardQuantities = "OwnedCardQuantitiesV2"
        }

        struct Entry: Decodable {
            let id: Int
            let type: String
            let quantity: Int

            enum CodingKeys: String, CodingKey {
                case id = "Id"
                case type = "Type"
                case quantity = "Quantity"
            }
        }
    }

    /// One row of the bundled official-id mapping (official_card_ids.json),
    /// generated from the LorcanaJSON dataset. JSON keys are shortened to keep
    /// the bundled file small.
    private struct OfficialCardRef: Decodable {
        let officialId: Int
        let setCode: String
        let cardNumber: Int
        let name: String

        enum CodingKeys: String, CodingKey {
            case officialId = "i"
            case setCode = "s"
            case cardNumber = "n"
            case name = "m"
        }
    }

    /// Official Ravensburger card id → set/number/name, loaded once on first use.
    /// Regenerate official_card_ids.json from LorcanaJSON when new sets release.
    private lazy var officialCardRefs: [Int: OfficialCardRef] = {
        guard let url = Bundle.main.url(forResource: "official_card_ids", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [OfficialCardRef]].self, from: data),
              let cards = decoded["cards"] else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: cards.map { ($0.officialId, $0) })
    }()

    /// Import a collection backup from the official Disney Lorcana app: each owned
    /// entry carries an official card id, which the bundled mapping resolves to
    /// set + card number for matching against the local database.
    private func matchOfficialBackup(_ text: String, cardIndex: CardIndex) -> ImportResult {
        var successful: [ImportedCard] = []
        var failed: [FailedImport] = []

        guard let data = text.data(using: .utf8),
              let backup = try? JSONDecoder().decode(OfficialBackup.self, from: data) else {
            let failure = FailedImport(originalLine: "Backup file", reason: "Couldn't read the official app backup file")
            return ImportResult(successful: [], failed: [failure], duplicates: [])
        }

        for entry in backup.ownedCardQuantities {
            guard entry.quantity > 0 else { continue }

            let variant: CardVariant = entry.type.lowercased() == "foiled" ? .foil : .normal

            guard let ref = officialCardRefs[entry.id] else {
                failed.append(FailedImport(
                    originalLine: "Official card id \(entry.id)",
                    reason: "Unknown card id \(entry.id) — the app may need an update for the newest set"
                ))
                continue
            }

            let setName = mapDreambornSetNumber(ref.setCode)
            let label = "\(ref.name) — official id \(entry.id)"

            if let setName,
               let matched = matchBySetAndNumber(setName: setName, number: ref.cardNumber, csvVariant: variant, cardIndex: cardIndex) {
                successful.append(ImportedCard(card: matched, quantity: entry.quantity, originalLine: label))
            } else if variant == .foil,
                      let base = findCard(name: ref.name, setName: setName, variant: .normal, cardIndex: cardIndex) {
                let foil = base.variant == .normal ? createFoilVariant(from: base) : base
                successful.append(ImportedCard(card: foil, quantity: entry.quantity, originalLine: label))
            } else if let matched = findCard(name: ref.name, setName: setName, variant: variant, cardIndex: cardIndex) {
                successful.append(ImportedCard(card: matched, quantity: entry.quantity, originalLine: label))
            } else {
                failed.append(FailedImport(originalLine: label, reason: "Card not found: '\(ref.name)'"))
            }
        }

        return ImportResult(successful: successful, failed: failed, duplicates: [])
    }

    /// Parse a CSV line into fields, handling quoted values
    func parseCSVFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    // Map Dreamborn set numbers to full set names
    func mapDreambornSetNumber(_ setNum: String) -> String? {
        switch setNum {
        case "001", "1": return "The First Chapter"
        case "002", "2": return "Rise of the Floodborn"
        case "003", "3": return "Into the Inklands"
        case "004", "4": return "Ursula's Return"
        case "005", "5": return "Shimmering Skies"
        case "006", "6": return "Azurite Sea"
        case "007", "7": return "Archazia's Island"
        case "008", "8": return "Reign of Jafar"
        case "009", "9": return "Fabled"
        case "010", "10": return "Whispers in the Well"
        case "011", "11": return "Winterspell"
        case "012", "12": return "Wilds Unknown"
        case "013", "13": return "Attack of the Vine!"
        case "P1": return "Promo Set 1"
        case "P2": return "Promo Set 2"
        case "P3": return "Promo Set 3"
        case "C1", "CP": return "Challenge Promo"
        case "C2": return "Lorcana Challenge Year 3"
        case "D23": return "D23 Collection"
        case "DIS", "EFA": return "EPCOT Festival of the Arts"
        default: return nil
        }
    }

    // Lorcana HQ format
    private func parseLorcanaHQLine(_ line: String) -> (name: String, set: String?, variant: CardVariant, quantity: Int)? {
        return parseTextListLine(line)
    }

    // MARK: - Card Matching

    private func createFoilVariant(from card: LorcanaCard) -> LorcanaCard {
        // Generate a foil-specific ID from the base card. Database ids like
        // "Fabled_9_Stitch___Alien_Dancer" contain no variant marker, so append
        // one — reusing the base id verbatim breaks SwiftUI list identity when
        // both the normal and foil copies are in the collection.
        let foilId = card.id.contains("_N_") ? card.id.replacing("_N_", with: "_F_") : card.id + "_Foil"

        return LorcanaCard(
            id: foilId,
            name: card.name,
            cost: card.cost,
            type: card.type,
            rarity: card.rarity,
            setName: card.setName,
            cardText: card.cardText,
            imageUrl: card.imageUrl,
            price: card.price,
            variant: .foil,
            cardNumber: card.cardNumber,
            uniqueId: card.uniqueId,
            inkwell: card.inkwell,
            strength: card.strength,
            willpower: card.willpower,
            lore: card.lore,
            franchise: card.franchise,
            inkColor: card.inkColor
        )
    }

    /// Lookup tables built once per import so matching doesn't rescan (and
    /// re-normalize) the entire card database for every line of the file.
    struct CardIndex {
        private let byName: [String: [LorcanaCard]]
        private let bySetAndNumber: [String: [LorcanaCard]]
        private let normalizedEntries: [(name: String, card: LorcanaCard)]

        init(cards: [LorcanaCard]) {
            var byName: [String: [LorcanaCard]] = [:]
            var bySetAndNumber: [String: [LorcanaCard]] = [:]
            var normalizedEntries: [(name: String, card: LorcanaCard)] = []

            for card in cards {
                let normalized = ImportService.shared.normalizeName(card.name)
                byName[normalized, default: []].append(card)
                normalizedEntries.append((normalized, card))

                if let number = card.cardNumber {
                    let key = "\(ImportService.shared.normalizeSetName(card.setName))|\(number)"
                    bySetAndNumber[key, default: []].append(card)
                }
            }

            self.byName = byName
            self.bySetAndNumber = bySetAndNumber
            self.normalizedEntries = normalizedEntries
        }

        func cards(named normalizedName: String) -> [LorcanaCard] {
            byName[normalizedName] ?? []
        }

        /// `setName` must already be normalized via `normalizeSetName`
        func cards(setName: String, number: Int) -> [LorcanaCard] {
            bySetAndNumber["\(setName)|\(number)"] ?? []
        }

        func fuzzyMatches(for normalizedName: String) -> [LorcanaCard] {
            normalizedEntries
                .filter { $0.name.contains(normalizedName) || normalizedName.contains($0.name) }
                .map { $0.card }
        }
    }

    private func findCard(name: String, setName: String?, variant: CardVariant, cardIndex: CardIndex) -> LorcanaCard? {
        let normalizedName = normalizeName(name)
        let candidates = cardIndex.cards(named: normalizedName)

        // Priority 1: Exact name + set + variant
        if let set = setName {
            let normalizedSet = normalizeSetName(set)

            if let exactMatch = candidates.first(where: {
                normalizeSetName($0.setName) == normalizedSet &&
                $0.variant == variant
            }) {
                return exactMatch
            }
        }

        // Priority 2: Exact name + variant (any set)
        if let match = candidates.first(where: { $0.variant == variant }) {
            return match
        }

        // Priority 3: Exact name + set (any variant) — for cards where variant
        // isn't in the database (e.g., foils stored as normal)
        if let set = setName {
            let normalizedSet = normalizeSetName(set)

            if let match = candidates.first(where: {
                normalizeSetName($0.setName) == normalizedSet
            }) {
                return match
            }
        }

        // Priority 4: Exact name only (any set, any variant)
        if let match = candidates.first {
            return match
        }

        // Priority 5: Fuzzy match — card name contains search or vice versa
        let fuzzyMatches = cardIndex.fuzzyMatches(for: normalizedName)

        if let bestMatch = fuzzyMatches.first(where: { $0.variant == variant }) {
            return bestMatch
        }

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
        let normalized = setName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing("’", with: "'")
            .replacing("‘", with: "'")

        // Map common abbreviations
        let abbreviations: [String: String] = [
            "tfc": "the first chapter",
            "rotf": "rise of the floodborn",
            "iti": "into the inklands",
            "urs": "ursula's return",
            "ssk": "shimmering skies",
            "as": "azurite sea",
            "ari": "archazia's island",
            "roj": "reign of jafar",
            "fab": "fabled",
            "wiw": "whispers in the well",
            "win": "winterspell"
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

    // MARK: - Export

    /// Generate a canonical Dreamborn-format CSV (the 7-column layout Dreamborn
    /// itself exports): `Set Number,Card Number,Variant,Count,Name,Color,Rarity`.
    ///
    /// Set numbers come from sets.json metadata — no hardcoded map to forget on
    /// new-set day. Special printings (Enchanted/Epic/Iconic) are emitted as
    /// `foil` rows at their own card numbers, matching real Dreamborn exports;
    /// cards whose set has no number (or that lack a card number) are skipped.
    func exportDreambornCSV(_ entries: [(card: LorcanaCard, quantity: Int)]) -> String {
        var setNumbers: [String: String] = [:]
        for set in SetsDataManager.shared.getAllSets() {
            if let number = set.setNumber, !number.isEmpty {
                setNumbers[set.name] = Int(number).map { String(format: "%03d", $0) } ?? number
            }
        }

        var rows: [(setNumber: String, cardNumber: Int, line: String)] = []
        for entry in entries {
            guard entry.quantity > 0,
                  let setNumber = setNumbers[entry.card.setName],
                  let cardNumber = entry.card.cardNumber else { continue }

            let variant: String
            switch entry.card.variant {
            case .foil, .enchanted, .epic, .iconic:
                // Special printings only exist foiled — Dreamborn marks them "foil"
                variant = "foil"
            case .normal, .promo, .borderless:
                variant = "normal"
            }

            let color = entry.card.inkColor ?? ""
            let line = "\(setNumber),\(cardNumber),\(variant),\(entry.quantity),\(entry.card.name),\(color),\(entry.card.rarity.rawValue)"
            rows.append((setNumber, cardNumber, line))
        }

        rows.sort {
            $0.setNumber != $1.setNumber ? $0.setNumber < $1.setNumber : $0.cardNumber < $1.cardNumber
        }

        return "Set Number,Card Number,Variant,Count,Name,Color,Rarity\n"
            + rows.map(\.line).joined(separator: "\n")
            + (rows.isEmpty ? "" : "\n")
    }
}
