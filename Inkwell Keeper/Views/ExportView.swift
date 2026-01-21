//
//  ExportView.swift
//  Inkwell Keeper
//
//  Export collections to CSV format
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export Field Definition

enum ExportField: String, CaseIterable, Identifiable {
    // Core fields (on by default)
    case cardName = "Card Name"
    case setName = "Set Name"
    case cardNumber = "Card Number"
    case variant = "Variant"
    case quantity = "Quantity"

    // Card details
    case rarity = "Rarity"
    case inkColor = "Ink Color"
    case cardType = "Card Type"
    case cost = "Cost"

    // Stats (for characters)
    case strength = "Strength"
    case willpower = "Willpower"
    case lore = "Lore"
    case inkwell = "Inkable"

    // Additional info
    case franchise = "Franchise"
    case price = "Price"
    case uniqueId = "Unique ID"

    // Collection-specific
    case condition = "Condition"
    case notes = "Notes"
    case dateAdded = "Date Added"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cardName: return "textformat"
        case .setName: return "rectangle.stack"
        case .cardNumber: return "number"
        case .variant: return "sparkles"
        case .quantity: return "plus.circle"
        case .rarity: return "star"
        case .inkColor: return "paintpalette"
        case .cardType: return "tag"
        case .cost: return "dollarsign.circle"
        case .strength: return "bolt"
        case .willpower: return "shield"
        case .lore: return "book"
        case .inkwell: return "drop"
        case .franchise: return "film"
        case .price: return "banknote"
        case .uniqueId: return "qrcode"
        case .condition: return "checkmark.seal"
        case .notes: return "note.text"
        case .dateAdded: return "calendar"
        }
    }

    var description: String {
        switch self {
        case .cardName: return "Name of the card"
        case .setName: return "Set the card belongs to"
        case .cardNumber: return "Collector number in set"
        case .variant: return "Normal, Foil, Enchanted, etc."
        case .quantity: return "How many copies you own"
        case .rarity: return "Common to Legendary"
        case .inkColor: return "Amber, Amethyst, etc."
        case .cardType: return "Character, Action, Item, etc."
        case .cost: return "Ink cost to play"
        case .strength: return "Character strength stat"
        case .willpower: return "Character willpower stat"
        case .lore: return "Lore value when questing"
        case .inkwell: return "Can be used as ink"
        case .franchise: return "Disney franchise"
        case .price: return "Estimated card value"
        case .uniqueId: return "Unique identifier (e.g., TFC-001)"
        case .condition: return "Card condition"
        case .notes: return "Your personal notes"
        case .dateAdded: return "When added to collection"
        }
    }

    /// Fields that are on by default
    static var defaultFields: Set<ExportField> {
        [.cardName, .setName, .cardNumber, .variant, .quantity]
    }

    /// Group fields by category for UI
    static var coreFields: [ExportField] {
        [.cardName, .setName, .cardNumber, .variant, .quantity]
    }

    static var cardDetailFields: [ExportField] {
        [.rarity, .inkColor, .cardType, .cost]
    }

    static var statFields: [ExportField] {
        [.strength, .willpower, .lore, .inkwell]
    }

    static var additionalFields: [ExportField] {
        [.franchise, .price, .uniqueId]
    }

    static var collectionFields: [ExportField] {
        [.condition, .notes, .dateAdded]
    }
}

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var collectionManager: CollectionManager

    @State private var exportOption: ExportOption = .collection
    @State private var selectedSets: Set<String> = []
    @State private var exportFormat: ExportFormat = .standard
    @State private var selectedFields: Set<ExportField> = ExportField.defaultFields
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var showingFieldSelection = false

    @StateObject private var dataManager = SetsDataManager.shared

    enum ExportFormat: String, CaseIterable {
        case standard = "Custom CSV"
        case dreambornBulk = "Dreamborn Bulk Add"
        case dreambornCollection = "Dreamborn Collection"
        case lorcanaHQ = "Lorcana HQ"
        case jsonBackup = "JSON Backup"

        var description: String {
            switch self {
            case .standard:
                return "Choose exactly which fields to export"
            case .dreambornBulk:
                return "Set Number, Card Number, Variant, Count"
            case .dreambornCollection:
                return "Normal, Foil, Name, Set, Card Number, Color, Rarity"
            case .lorcanaHQ:
                return "Quantity x Card Name - Subtitle (Set)"
            case .jsonBackup:
                return "Full data backup - can be restored later"
            }
        }

        var icon: String {
            switch self {
            case .standard: return "slider.horizontal.3"
            case .dreambornBulk: return "arrow.up.square"
            case .dreambornCollection: return "tablecells"
            case .lorcanaHQ: return "list.bullet"
            case .jsonBackup: return "externaldrive"
            }
        }

        var fileExtension: String {
            switch self {
            case .jsonBackup: return "json"
            default: return "csv"
            }
        }

        /// Whether this format supports custom field selection
        var supportsFieldSelection: Bool {
            self == .standard
        }
    }

    enum ExportOption: String, CaseIterable {
        case collection = "My Collection"
        case wishlist = "Wishlist"
        case specificSets = "Specific Sets"
        case everything = "Everything"

        var icon: String {
            switch self {
            case .collection: return "square.stack.3d.up.fill"
            case .wishlist: return "heart.fill"
            case .specificSets: return "rectangle.stack.fill"
            case .everything: return "square.grid.2x2.fill"
            }
        }

        var description: String {
            switch self {
            case .collection:
                return "Export all cards in your collection"
            case .wishlist:
                return "Export your wishlist cards"
            case .specificSets:
                return "Choose specific sets to export"
            case .everything:
                return "Export collection + wishlist"
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Info
                    headerSection

                    // Export Options
                    exportOptionsSection

                    // Set Selection (if specific sets selected)
                    if exportOption == .specificSets {
                        setSelectionSection
                    }

                    // Export Format Selection
                    formatSelectionSection

                    // Format Options (only for custom CSV)
                    if exportFormat.supportsFieldSelection {
                        formatOptionsSection
                    }

                    // Preview Stats
                    previewStatsSection

                    // Export Button
                    if !isExporting {
                        exportButton
                    } else {
                        ProgressView("Generating export...")
                            .padding()
                    }
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("Export Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.up.doc.fill")
                .font(.system(size: 50))
                .foregroundColor(.lorcanaGold)

            Text("Export Your Collection")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Generate a CSV file that you can backup, share, or import into other apps")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What to Export")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(ExportOption.allCases, id: \.self) { option in
                Button(action: {
                    exportOption = option
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: exportOption == option ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.lorcanaGold)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(.lorcanaGold)
                                Text(option.rawValue)
                                    .font(.body)
                                    .foregroundColor(.white)
                            }

                            Text(option.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        // Show count
                        Text("\(getCardCount(for: option)) cards")
                            .font(.caption)
                            .foregroundColor(.lorcanaGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.lorcanaGold.opacity(0.2))
                            )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(exportOption == option ? Color.lorcanaGold.opacity(0.2) : Color.lorcanaDark.opacity(0.4))
                    )
                }
            }
        }
    }

    private var setSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Sets")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    if selectedSets.count == availableSets.count {
                        selectedSets.removeAll()
                    } else {
                        selectedSets = Set(availableSets)
                    }
                }) {
                    Text(selectedSets.count == availableSets.count ? "Deselect All" : "Select All")
                        .font(.caption)
                        .foregroundColor(.lorcanaGold)
                }
            }

            ForEach(availableSets, id: \.self) { setName in
                Button(action: {
                    if selectedSets.contains(setName) {
                        selectedSets.remove(setName)
                    } else {
                        selectedSets.insert(setName)
                    }
                }) {
                    HStack {
                        Image(systemName: selectedSets.contains(setName) ? "checkmark.square.fill" : "square")
                            .foregroundColor(.lorcanaGold)

                        Text(setName)
                            .font(.body)
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(getCardCountForSet(setName)) cards")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.lorcanaDark.opacity(0.4))
                    )
                }
            }
        }
    }

    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Format")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(ExportFormat.allCases, id: \.self) { format in
                Button(action: {
                    exportFormat = format
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: exportFormat == format ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.lorcanaGold)
                            .font(.title3)

                        Image(systemName: format.icon)
                            .foregroundColor(.lorcanaGold)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(format.rawValue)
                                    .font(.body)
                                    .foregroundColor(.white)

                                Text(".\(format.fileExtension)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.gray.opacity(0.3))
                                    )
                            }

                            Text(format.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(exportFormat == format ? Color.lorcanaGold.opacity(0.2) : Color.lorcanaDark.opacity(0.4))
                    )
                }
            }
        }
    }

    private var formatOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Export Fields")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(selectedFields.count) selected")
                    .font(.caption)
                    .foregroundColor(.lorcanaGold)
            }

            // Quick summary of selected fields
            Text(selectedFieldsSummary)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)

            Button(action: { showingFieldSelection = true }) {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(.lorcanaGold)

                    Text("Choose Fields to Export")
                        .font(.body)
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.lorcanaDark.opacity(0.4))
                )
            }

            // Quick toggles for common presets
            HStack(spacing: 8) {
                presetButton("Basic", fields: [.cardName, .setName, .quantity])
                presetButton("Standard", fields: ExportField.defaultFields)
                presetButton("Full", fields: Set(ExportField.allCases))
            }
        }
        .sheet(isPresented: $showingFieldSelection) {
            FieldSelectionView(selectedFields: $selectedFields)
        }
    }

    private var selectedFieldsSummary: String {
        let sortedFields = ExportField.allCases.filter { selectedFields.contains($0) }
        return sortedFields.map { $0.rawValue }.joined(separator: ", ")
    }

    private func presetButton(_ title: String, fields: Set<ExportField>) -> some View {
        Button(action: { selectedFields = fields }) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(selectedFields == fields ? .black : .lorcanaGold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selectedFields == fields ? Color.lorcanaGold : Color.lorcanaGold.opacity(0.2))
                )
        }
    }

    private var previewStatsSection: some View {
        VStack(spacing: 12) {
            Text("Export Preview")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                statBox(
                    title: "Cards",
                    value: "\(getTotalCardsToExport())",
                    icon: "rectangle.stack.fill"
                )

                statBox(
                    title: "Unique",
                    value: "\(getUniqueCardsToExport())",
                    icon: "sparkles"
                )

                if selectedFields.contains(.quantity) {
                    statBox(
                        title: "Total Qty",
                        value: "\(getTotalQuantity())",
                        icon: "number"
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    private func statBox(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.lorcanaGold)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
        )
    }

    private var exportButton: some View {
        Button(action: performExport) {
            HStack {
                Image(systemName: "arrow.up.doc.fill")
                Text("Export to CSV")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LorcanaButtonStyle())
        .disabled(exportOption == .specificSets && selectedSets.isEmpty)
    }

    // MARK: - Helper Methods

    private var availableSets: [String] {
        let allSets = Set(collectionManager.collectedCards.map { $0.setName })
        return Array(allSets).sorted()
    }

    private func getCardCount(for option: ExportOption) -> Int {
        switch option {
        case .collection:
            return collectionManager.collectedCards.count
        case .wishlist:
            return collectionManager.wishlistCards.count
        case .specificSets:
            return selectedSets.isEmpty ? 0 : collectionManager.collectedCards.filter { selectedSets.contains($0.setName) }.count
        case .everything:
            return collectionManager.collectedCards.count + collectionManager.wishlistCards.count
        }
    }

    private func getCardCountForSet(_ setName: String) -> Int {
        return collectionManager.collectedCards.filter { $0.setName == setName }.count
    }

    private func getTotalCardsToExport() -> Int {
        getCardsToExport().count
    }

    private func getUniqueCardsToExport() -> Int {
        let cards = getCardsToExport()
        let uniqueNames = Set(cards.map { "\($0.name)|\($0.setName)|\($0.variant.rawValue)" })
        return uniqueNames.count
    }

    private func getTotalQuantity() -> Int {
        let cards = getCardsToExport()
        var totalQty = 0

        for card in cards {
            let qty = collectionManager.getCollectedQuantityByName(card.name, setName: card.setName, variant: card.variant)
            totalQty += qty
        }

        return totalQty
    }

    private func getCardsToExport() -> [LorcanaCard] {
        switch exportOption {
        case .collection:
            return collectionManager.collectedCards
        case .wishlist:
            return collectionManager.wishlistCards
        case .specificSets:
            return collectionManager.collectedCards.filter { selectedSets.contains($0.setName) }
        case .everything:
            return collectionManager.collectedCards + collectionManager.wishlistCards
        }
    }

    private func performExport() {
        isExporting = true

        Task {
            let cards = getCardsToExport()

            // Generate export content
            let content = generateExportContent(from: cards)

            // Create temporary file with correct extension
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "ink_well_keeper_export_\(timestamp).\(exportFormat.fileExtension)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            do {
                try content.write(to: tempURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    exportedFileURL = tempURL
                    isExporting = false
                    showingShareSheet = true
                }
            } catch {
                print("❌ [Export] Failed to write file: \(error)")
                await MainActor.run {
                    isExporting = false
                }
            }
        }
    }

    private func generateExportContent(from cards: [LorcanaCard]) -> String {
        switch exportFormat {
        case .standard:
            return generateStandardCSV(from: cards)
        case .dreambornBulk:
            return generateDreambornBulkCSV(from: cards)
        case .dreambornCollection:
            return generateDreambornCollectionCSV(from: cards)
        case .lorcanaHQ:
            return generateLorcanaHQExport(from: cards)
        case .jsonBackup:
            return generateJSONBackup(from: cards)
        }
    }

    private func generateStandardCSV(from cards: [LorcanaCard]) -> String {
        var csv = ""

        // Build header dynamically based on selected fields (maintain consistent order)
        let orderedFields = ExportField.allCases.filter { selectedFields.contains($0) }
        let headerColumns = orderedFields.map { $0.rawValue }
        csv += headerColumns.joined(separator: ",") + "\n"

        // Group cards by name+set+variant and count quantities
        var cardGroups: [String: (card: LorcanaCard, quantity: Int, collectedCard: CollectedCard?)] = [:]

        for card in cards {
            let key = "\(card.name)|\(card.setName)|\(card.variant.rawValue)"

            if let existing = cardGroups[key] {
                cardGroups[key] = (card, existing.quantity + 1, existing.collectedCard)
            } else {
                let qty = collectionManager.getCollectedQuantityByName(card.name, setName: card.setName, variant: card.variant)
                // Find the CollectedCard for additional fields like condition, notes
                let collectedCard = collectionManager.getCollectedCardData(for: card)
                cardGroups[key] = (card, qty > 0 ? qty : 1, collectedCard)
            }
        }

        // Sort by set, then card number, then name
        let sortedGroups = cardGroups.values.sorted { first, second in
            if first.card.setName != second.card.setName {
                return first.card.setName < second.card.setName
            }
            if let num1 = first.card.cardNumber, let num2 = second.card.cardNumber, num1 != num2 {
                return num1 < num2
            }
            return first.card.name < second.card.name
        }

        // Generate rows
        for group in sortedGroups {
            var rowColumns: [String] = []

            for field in orderedFields {
                let value = getFieldValue(field: field, card: group.card, quantity: group.quantity, collectedCard: group.collectedCard)
                rowColumns.append(value)
            }

            csv += rowColumns.joined(separator: ",") + "\n"
        }

        return csv
    }

    private func getFieldValue(field: ExportField, card: LorcanaCard, quantity: Int, collectedCard: CollectedCard?) -> String {
        switch field {
        case .cardName:
            return "\"\(card.name.replacingOccurrences(of: "\"", with: "\"\""))\""
        case .setName:
            return "\"\(card.setName.replacingOccurrences(of: "\"", with: "\"\""))\""
        case .cardNumber:
            if let cardNum = card.cardNumber {
                return String(cardNum)
            } else if let uniqueId = card.uniqueId, !uniqueId.isEmpty {
                let components = uniqueId.split(separator: "-")
                if components.count == 2, let num = Int(components[1]) {
                    return String(num)
                }
            }
            return ""
        case .variant:
            return "\"\(card.variant.displayName)\""
        case .quantity:
            return String(quantity)
        case .rarity:
            return "\"\(card.rarity.rawValue)\""
        case .inkColor:
            return "\"\(card.inkColor ?? "")\""
        case .cardType:
            return "\"\(card.type)\""
        case .cost:
            return String(card.cost)
        case .strength:
            if let strength = card.strength {
                return String(strength)
            }
            return ""
        case .willpower:
            if let willpower = card.willpower {
                return String(willpower)
            }
            return ""
        case .lore:
            if let lore = card.lore {
                return String(lore)
            }
            return ""
        case .inkwell:
            if let inkwell = card.inkwell {
                return inkwell ? "Yes" : "No"
            }
            return ""
        case .franchise:
            return "\"\(card.franchise ?? "")\""
        case .price:
            if let price = card.price {
                return String(format: "%.2f", price)
            }
            return ""
        case .uniqueId:
            return "\"\(card.uniqueId ?? "")\""
        case .condition:
            return "\"\(collectedCard?.condition ?? "")\""
        case .notes:
            let notes = collectedCard?.notes ?? ""
            return "\"\(notes.replacingOccurrences(of: "\"", with: "\"\""))\""
        case .dateAdded:
            if let date = collectedCard?.dateAdded {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return "\"\(formatter.string(from: date))\""
            }
            return ""
        }
    }

    private func generateDreambornBulkCSV(from cards: [LorcanaCard]) -> String {
        var csv = "Set Number,Card Number,Variant,Count\n"

        // Group cards by set+card number+variant and count quantities
        var cardGroups: [String: (card: LorcanaCard, quantity: Int, cardNumber: Int)] = [:]

        for card in cards {
            // Try to get card number from cardNumber field first, then parse from uniqueId
            var cardNumber: Int? = card.cardNumber

            if cardNumber == nil, let uniqueId = card.uniqueId, !uniqueId.isEmpty {
                // Parse card number from uniqueId (format: "ROJ-001", "TFC-123", etc.)
                let components = uniqueId.split(separator: "-")
                if components.count == 2, let num = Int(components[1]) {
                    cardNumber = num
                }
            }

            // Skip cards without a valid card number
            guard let validCardNumber = cardNumber else {
                print("⚠️ [Dreamborn Export] Skipping card without card number: \(card.name)")
                continue
            }

            let key = "\(card.setName)|\(validCardNumber)|\(card.variant.rawValue)"

            if let existing = cardGroups[key] {
                cardGroups[key] = (card, existing.quantity + 1, validCardNumber)
            } else {
                let qty = collectionManager.getCollectedQuantityByName(card.name, setName: card.setName, variant: card.variant)
                cardGroups[key] = (card, qty > 0 ? qty : 1, validCardNumber)
            }
        }

        // Sort by set number then card number
        let sortedGroups = cardGroups.values.sorted { first, second in
            let setNum1 = getSetNumber(for: first.card.setName)
            let setNum2 = getSetNumber(for: second.card.setName)

            if setNum1 != setNum2 {
                return setNum1 < setNum2  // String comparison works fine with 3-digit format
            }
            return first.cardNumber < second.cardNumber
        }

        // Generate rows
        for group in sortedGroups {
            let setNumber = getSetNumber(for: group.card.setName)

            // Map variants to Dreamborn format
            let variant: String
            switch group.card.variant {
            case .foil:
                variant = "foil"
            case .enchanted:
                variant = "enchanted"
            case .epic, .iconic:
                // Dreamborn might use different names for these - using "normal" as fallback
                variant = "normal"
            case .promo:
                variant = "promo"
            case .normal:
                variant = "normal"
            case .borderless:
                variant = "borderless"
            }

            let quantity = group.quantity

            csv += "\(setNumber),\(group.cardNumber),\(variant),\(quantity)\n"
        }

        return csv
    }

    private func getSetNumber(for setName: String) -> String {
        // Map set names to Dreamborn set numbers (3-digit format)
        switch setName {
        case "The First Chapter": return "001"
        case "Rise of the Floodborn": return "002"
        case "Into the Inklands": return "003"
        case "Ursula's Return": return "004"
        case "Shimmering Skies": return "005"
        case "Azurite Sea": return "006"
        case "Archazia's Island": return "007"
        case "Reign of Jafar": return "008"
        case "Whispers in the Well": return "009"
        case "Fabled": return "010"
        default: return "999"  // Unknown sets
        }
    }

    // MARK: - Dreamborn Collection Export
    // Format: Normal,Foil,Name,Set,Card Number,Color,Rarity,Price,Foil Price

    private func generateDreambornCollectionCSV(from cards: [LorcanaCard]) -> String {
        var csv = "Normal,Foil,Name,Set,Card Number,Color,Rarity,Price,Foil Price\n"

        // Group cards by name+set to combine normal and foil quantities
        var cardGroups: [String: (card: LorcanaCard, normalQty: Int, foilQty: Int)] = [:]

        for card in cards {
            let key = "\(card.name)|\(card.setName)"

            let qty = collectionManager.getCollectedQuantityByName(card.name, setName: card.setName, variant: card.variant)
            let actualQty = qty > 0 ? qty : 1

            if var existing = cardGroups[key] {
                if card.variant == .foil {
                    existing.foilQty += actualQty
                } else {
                    existing.normalQty += actualQty
                }
                cardGroups[key] = existing
            } else {
                if card.variant == .foil {
                    cardGroups[key] = (card, 0, actualQty)
                } else {
                    cardGroups[key] = (card, actualQty, 0)
                }
            }
        }

        // Sort by set number then card number
        let sortedGroups = cardGroups.values.sorted { first, second in
            let setNum1 = getSetNumber(for: first.card.setName)
            let setNum2 = getSetNumber(for: second.card.setName)

            if setNum1 != setNum2 {
                return setNum1 < setNum2
            }
            if let num1 = first.card.cardNumber, let num2 = second.card.cardNumber {
                return num1 < num2
            }
            return first.card.name < second.card.name
        }

        // Generate rows
        for group in sortedGroups {
            let name = group.card.name.replacingOccurrences(of: "\"", with: "\"\"")
            let setNumber = getSetNumber(for: group.card.setName)
            let cardNumber = group.card.cardNumber ?? 0
            let color = group.card.inkColor ?? ""
            let rarity = group.card.rarity.rawValue
            let price = group.card.price ?? 0.0

            csv += "\(group.normalQty),\(group.foilQty),\"\(name)\",\(setNumber),\(cardNumber),\(color),\(rarity),\(String(format: "%.2f", price)),\(String(format: "%.2f", price * 2))\n"
        }

        return csv
    }

    // MARK: - Lorcana HQ Export
    // Format: Quantity x Card Name - Subtitle (Set Name)

    private func generateLorcanaHQExport(from cards: [LorcanaCard]) -> String {
        var lines: [String] = []

        // Group cards by name+set+variant
        var cardGroups: [String: (card: LorcanaCard, quantity: Int)] = [:]

        for card in cards {
            let key = "\(card.name)|\(card.setName)|\(card.variant.rawValue)"

            if let existing = cardGroups[key] {
                cardGroups[key] = (card, existing.quantity + 1)
            } else {
                let qty = collectionManager.getCollectedQuantityByName(card.name, setName: card.setName, variant: card.variant)
                cardGroups[key] = (card, qty > 0 ? qty : 1)
            }
        }

        // Sort by set then name
        let sortedGroups = cardGroups.values.sorted { first, second in
            if first.card.setName != second.card.setName {
                return first.card.setName < second.card.setName
            }
            return first.card.name < second.card.name
        }

        // Generate lines
        for group in sortedGroups {
            let cardName = group.card.name
            let setName = group.card.setName
            let quantity = group.quantity
            let variant = group.card.variant != .normal ? " [\(group.card.variant.displayName)]" : ""

            // Format: "2x Ariel - On Human Legs (The First Chapter) [Foil]"
            lines.append("\(quantity)x \(cardName) (\(setName))\(variant)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - JSON Backup Export
    // Full data backup with all card information

    private func generateJSONBackup(from cards: [LorcanaCard]) -> String {
        struct ExportCard: Codable {
            let id: String
            let name: String
            let setName: String
            let cardNumber: Int?
            let uniqueId: String?
            let variant: String
            let quantity: Int
            let rarity: String
            let inkColor: String?
            let cardType: String
            let cost: Int
            let strength: Int?
            let willpower: Int?
            let lore: Int?
            let inkwell: Bool?
            let franchise: String?
            let price: Double?
            let condition: String?
            let notes: String?
            let dateAdded: String?
            let imageUrl: String
        }

        struct BackupData: Codable {
            let exportDate: String
            let appVersion: String
            let totalCards: Int
            let totalQuantity: Int
            let cards: [ExportCard]
        }

        // Group cards
        var cardGroups: [String: (card: LorcanaCard, quantity: Int, collectedCard: CollectedCard?)] = [:]

        for card in cards {
            let key = "\(card.name)|\(card.setName)|\(card.variant.rawValue)"

            if let existing = cardGroups[key] {
                cardGroups[key] = (card, existing.quantity + 1, existing.collectedCard)
            } else {
                let qty = collectionManager.getCollectedQuantityByName(card.name, setName: card.setName, variant: card.variant)
                let collectedCard = collectionManager.getCollectedCardData(for: card)
                cardGroups[key] = (card, qty > 0 ? qty : 1, collectedCard)
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        var exportCards: [ExportCard] = []

        for group in cardGroups.values {
            let card = group.card
            let collectedCard = group.collectedCard

            let dateAddedStr: String?
            if let date = collectedCard?.dateAdded {
                dateAddedStr = dateFormatter.string(from: date)
            } else {
                dateAddedStr = nil
            }

            let exportCard = ExportCard(
                id: card.id,
                name: card.name,
                setName: card.setName,
                cardNumber: card.cardNumber,
                uniqueId: card.uniqueId,
                variant: card.variant.rawValue,
                quantity: group.quantity,
                rarity: card.rarity.rawValue,
                inkColor: card.inkColor,
                cardType: card.type,
                cost: card.cost,
                strength: card.strength,
                willpower: card.willpower,
                lore: card.lore,
                inkwell: card.inkwell,
                franchise: card.franchise,
                price: card.price,
                condition: collectedCard?.condition,
                notes: collectedCard?.notes,
                dateAdded: dateAddedStr,
                imageUrl: card.imageUrl
            )
            exportCards.append(exportCard)
        }

        exportCards.sort { first, second in
            if first.setName != second.setName {
                return first.setName < second.setName
            }
            return first.name < second.name
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        let backupData = BackupData(
            exportDate: dateFormatter.string(from: Date()),
            appVersion: appVersion,
            totalCards: exportCards.count,
            totalQuantity: exportCards.reduce(0) { $0 + $1.quantity },
            cards: exportCards
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let jsonData = try? encoder.encode(backupData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "{\"error\": \"Failed to generate JSON backup\"}"
    }
}

// MARK: - Field Selection View

struct FieldSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFields: Set<ExportField>

    var body: some View {
        NavigationView {
            List {
                // Core Fields
                Section("Core Fields") {
                    ForEach(ExportField.coreFields) { field in
                        fieldRow(field)
                    }
                }

                // Card Details
                Section("Card Details") {
                    ForEach(ExportField.cardDetailFields) { field in
                        fieldRow(field)
                    }
                }

                // Character Stats
                Section("Character Stats") {
                    ForEach(ExportField.statFields) { field in
                        fieldRow(field)
                    }
                }

                // Additional Info
                Section("Additional Info") {
                    ForEach(ExportField.additionalFields) { field in
                        fieldRow(field)
                    }
                }

                // Collection Data
                Section("Collection Data") {
                    ForEach(ExportField.collectionFields) { field in
                        fieldRow(field)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Fields")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        selectedFields = ExportField.defaultFields
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func fieldRow(_ field: ExportField) -> some View {
        Button(action: { toggleField(field) }) {
            HStack(spacing: 12) {
                Image(systemName: selectedFields.contains(field) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedFields.contains(field) ? .lorcanaGold : .gray)
                    .font(.title3)

                Image(systemName: field.icon)
                    .foregroundColor(.lorcanaGold)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(field.rawValue)
                        .foregroundColor(.primary)
                    Text(field.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()
            }
        }
    }

    private func toggleField(_ field: ExportField) {
        if selectedFields.contains(field) {
            // Don't allow removing the last field
            if selectedFields.count > 1 {
                selectedFields.remove(field)
            }
        } else {
            selectedFields.insert(field)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportView()
        .environmentObject(CollectionManager())
}
