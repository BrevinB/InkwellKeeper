//
//  ExportView.swift
//  Inkwell Keeper
//
//  Export collections to CSV format
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var collectionManager: CollectionManager

    @State private var exportOption: ExportOption = .collection
    @State private var selectedSets: Set<String> = []
    @State private var exportFormat: ExportFormat = .standard
    @State private var includeQuantities = true
    @State private var includeVariants = true
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?

    @StateObject private var dataManager = SetsDataManager.shared

    enum ExportFormat: String, CaseIterable {
        case standard = "Standard CSV"
        case dreamborn = "Dreamborn.ink Bulk Add"

        var description: String {
            switch self {
            case .standard:
                return "Card Name, Set Name, Variant, Quantity"
            case .dreamborn:
                return "Set Number, Card Number, Variant, Count"
            }
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

                    // Format Options
                    if exportFormat == .standard {
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

                        VStack(alignment: .leading, spacing: 4) {
                            Text(format.rawValue)
                                .font(.body)
                                .foregroundColor(.white)

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
            Text("Export Options")
                .font(.headline)
                .foregroundColor(.white)

            Toggle(isOn: $includeQuantities) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Include Quantities")
                        .font(.body)
                        .foregroundColor(.white)
                    Text("Export how many copies you own")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .lorcanaGold))
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lorcanaDark.opacity(0.4))
            )

            Toggle(isOn: $includeVariants) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Include Variants")
                        .font(.body)
                        .foregroundColor(.white)
                    Text("Specify card variants (Normal, Foil, Enchanted)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .lorcanaGold))
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lorcanaDark.opacity(0.4))
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

                if includeQuantities {
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

            // Generate CSV with quantities if needed
            var csv = generateCSV(from: cards)

            // Create temporary file
            let fileName = "ink_well_keeper_export_\(Date().timeIntervalSince1970).csv"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            do {
                try csv.write(to: tempURL, atomically: true, encoding: .utf8)

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

    private func generateCSV(from cards: [LorcanaCard]) -> String {
        if exportFormat == .dreamborn {
            return generateDreambornCSV(from: cards)
        } else {
            return generateStandardCSV(from: cards)
        }
    }

    private func generateStandardCSV(from cards: [LorcanaCard]) -> String {
        var csv = ""

        // Header
        if includeVariants && includeQuantities {
            csv += "Card Name,Set Name,Variant,Quantity\n"
        } else if includeVariants {
            csv += "Card Name,Set Name,Variant\n"
        } else if includeQuantities {
            csv += "Card Name,Set Name,Quantity\n"
        } else {
            csv += "Card Name,Set Name\n"
        }

        // Group cards by name+set+variant and count quantities
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

        // Sort by set and name
        let sortedGroups = cardGroups.values.sorted { first, second in
            if first.card.setName != second.card.setName {
                return first.card.setName < second.card.setName
            }
            return first.card.name < second.card.name
        }

        // Generate rows
        for group in sortedGroups {
            let name = group.card.name.replacingOccurrences(of: "\"", with: "\"\"")
            let set = group.card.setName.replacingOccurrences(of: "\"", with: "\"\"")
            let variant = group.card.variant.displayName
            let quantity = group.quantity

            if includeVariants && includeQuantities {
                csv += "\"\(name)\",\"\(set)\",\"\(variant)\",\(quantity)\n"
            } else if includeVariants {
                csv += "\"\(name)\",\"\(set)\",\"\(variant)\"\n"
            } else if includeQuantities {
                csv += "\"\(name)\",\"\(set)\",\(quantity)\n"
            } else {
                csv += "\"\(name)\",\"\(set)\"\n"
            }
        }

        return csv
    }

    private func generateDreambornCSV(from cards: [LorcanaCard]) -> String {
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
