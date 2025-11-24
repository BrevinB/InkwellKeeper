//
//  BulkImportView.swift
//  Inkwell Keeper
//
//  UI for bulk importing cards from various sources
//

import SwiftUI
import UniformTypeIdentifiers

struct BulkImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var collectionManager: CollectionManager

    @State private var importText = ""
    @State private var isProcessing = false
    @State private var importResult: ImportService.ImportResult?
    @State private var showingFilePicker = false
    @State private var showingResults = false
    @State private var isFileImport = false
    @State private var fileName: String?
    @State private var importProgress: Double = 0
    @State private var isAddingToCollection = false
    @State private var addProgress: Double = 0
    @State private var cardsAdded: Int = 0
    @State private var totalCardsToAdd: Int = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Instructions
                    instructionsSection

                    // Import Methods
                    importMethodsSection

                    // File Info or Text Input Area
                    if isFileImport {
                        fileInfoSection
                    } else {
                        textInputSection
                    }

                    // Process Button
                    if !importText.isEmpty && !isProcessing {
                        processButton
                    }

                    // Processing Indicator
                    if isProcessing {
                        processingSection
                    }
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("Bulk Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingResults) {
                if let result = importResult {
                    ImportResultsView(
                        result: result,
                        onConfirm: {
                            addCardsToCollection(result.successful)
                        },
                        onCancel: {
                            showingResults = false
                            importResult = nil
                        }
                    )
                    .environmentObject(collectionManager)
                }
            }
            .overlay {
                if isAddingToCollection {
                    addingToCollectionOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .animation(.easeInOut(duration: 0.3), value: isAddingToCollection)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .text, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    // MARK: - View Components

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How to Import", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(.lorcanaGold)

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: 1, text: "Import Dreamborn CSV file or paste card list")
                instructionRow(number: 2, text: "Review the matched cards")
                instructionRow(number: 3, text: "Confirm to add to collection")
            }
            .font(.caption)
            .foregroundColor(.gray)

            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Supported Formats:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.lorcanaGold)

                Text("• Dreamborn.ink CSV export (automatic)")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Text("• Text list: One card per line")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Text("  Examples:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.leading, 8)

                Text("  2x Mickey Mouse - Brave Little Tailor")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.leading, 16)

                Text("  Ariel - On Human Legs")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.leading, 16)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.bold)
                .foregroundColor(.lorcanaGold)
            Text(text)
        }
    }

    private var importMethodsSection: some View {
        VStack(spacing: 12) {
            Text("Choose Import Method")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button(action: { showingFilePicker = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.title)
                        Text("Dreamborn CSV")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Import from file")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaGold.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.lorcanaGold.opacity(0.4), lineWidth: 1)
                            )
                    )
                    .foregroundColor(.lorcanaGold)
                }

                Button(action: {
                    // Paste from clipboard
                    if let clipboardText = UIPasteboard.general.string {
                        importText = clipboardText
                        isFileImport = false
                        fileName = nil
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.title)
                        Text("Text List")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Paste card names")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaGold.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.lorcanaGold.opacity(0.4), lineWidth: 1)
                            )
                    )
                    .foregroundColor(.lorcanaGold)
                }
            }
        }
    }

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Imported File")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.largeTitle)
                        .foregroundColor(.lorcanaGold)

                    VStack(alignment: .leading, spacing: 4) {
                        if let fileName = fileName {
                            Text(fileName)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }

                        let lineCount = importText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
                        Text("\(lineCount) lines")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button(action: {
                        importText = ""
                        isFileImport = false
                        fileName = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaGold.opacity(0.1))
                )
            }
        }
    }

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card List")
                .font(.headline)
                .foregroundColor(.white)

            ZStack(alignment: .topLeading) {
                if importText.isEmpty {
                    Text("Paste your card list here...\n\nExamples:\n2x Mickey Mouse - Brave Little Tailor\nAriel - On Human Legs\nElsa - Snow Queen (Foil)")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(12)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $importText)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white)
            }
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
            )

            if !importText.isEmpty {
                HStack {
                    Text("\(importText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count) lines")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Button(action: {
                        importText = ""
                        isFileImport = false
                        fileName = nil
                    }) {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var processingSection: some View {
        VStack(spacing: 16) {
            ProgressView(value: importProgress) {
                Text("Processing import...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .tint(.lorcanaGold)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaDark.opacity(0.6))
            )

            if importProgress > 0 {
                Text("\(Int(importProgress * 100))% complete")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private var processButton: some View {
        Button(action: processImport) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                Text("Process Import")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LorcanaButtonStyle())
    }

    private var addingToCollectionOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(Color.lorcanaGold.opacity(0.2))
                        .frame(width: 100, height: 100)

                    if addProgress >= 1.0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.lorcanaGold)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: addProgress)
                    } else {
                        ProgressView()
                            .scaleEffect(2)
                            .tint(.lorcanaGold)
                    }
                }

                VStack(spacing: 12) {
                    Text(addProgress >= 1.0 ? "Complete!" : "Adding Cards to Collection")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if addProgress < 1.0 {
                        Text("\(cardsAdded) of \(totalCardsToAdd) cards added")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        Text("\(cardsAdded) cards added successfully")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }

                if addProgress < 1.0 {
                    ProgressView(value: addProgress)
                        .tint(.lorcanaGold)
                        .frame(width: 250)
                        .animation(.easeInOut(duration: 0.2), value: addProgress)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.lorcanaDark)
                    .shadow(color: .black.opacity(0.5), radius: 20)
            )
        }
    }

    // MARK: - Helper Methods

    private func detectFormat(from text: String) -> ImportService.ImportFormat {
        let firstLine = text.components(separatedBy: .newlines).first ?? ""

        // Check if it's a Dreamborn CSV (has the specific header or comma-separated with numbers at start)
        if firstLine.lowercased().contains("normal") &&
           firstLine.lowercased().contains("foil") &&
           firstLine.lowercased().contains("name") {
            return .dreamborn
        }

        // Check if any early line looks like Dreamborn format (starts with numbers, has quoted card name)
        let earlyLines = text.components(separatedBy: .newlines).prefix(5)
        for line in earlyLines where !line.isEmpty {
            // Pattern: number,number,"Card Name",
            if line.range(of: #"^\d+,\d+,"[^"]+","#, options: .regularExpression) != nil {
                return .dreamborn
            }
        }

        // Default to text list for manual entry
        return .textList
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                print("❌ [Import] No URL selected")
                return
            }

            print("📂 [Import] Selected file: \(url.lastPathComponent)")
            print("📂 [Import] File path: \(url.path)")

            // Start accessing security-scoped resource (important for iOS)
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                print("✅ [Import] Successfully read file: \(text.count) characters")
                importText = text
                isFileImport = true
                fileName = url.lastPathComponent
            } catch {
                print("❌ [Import] Failed to read file: \(error)")
                print("❌ [Import] Error details: \(error.localizedDescription)")

                // Show alert to user
                DispatchQueue.main.async {
                    // You could set a @State error message here to show in UI
                }
            }

        case .failure(let error):
            print("❌ [Import] File picker error: \(error)")
            print("❌ [Import] Error details: \(error.localizedDescription)")
        }
    }

    private func processImport() {
        isProcessing = true
        importProgress = 0

        Task {
            // Auto-detect format based on content
            let detectedFormat = detectFormat(from: importText)
            print("🔍 [Import] Auto-detected format: \(detectedFormat.description)")

            let result = await ImportService.shared.importFromText(
                importText,
                format: detectedFormat,
                progressCallback: { progress in
                    self.importProgress = progress
                }
            )

            await MainActor.run {
                isProcessing = false
                importProgress = 0
                importResult = result
                showingResults = true
            }
        }
    }

    private func addCardsToCollection(_ importedCards: [ImportService.ImportedCard]) {
        // Calculate total number of physical cards to add
        let totalCards = importedCards.reduce(0) { $0 + $1.quantity }

        // Show overlay and dismiss results sheet
        showingResults = false
        isAddingToCollection = true
        cardsAdded = 0
        totalCardsToAdd = totalCards
        addProgress = 0

        Task {
            var cardCount = 0
            let batchSize = totalCards > 500 ? 50 : (totalCards > 100 ? 10 : 1)
            var cardsInBatch = 0

            for imported in importedCards {
                for _ in 0..<imported.quantity {
                    collectionManager.addCard(imported.card)
                    cardCount += 1
                    cardsInBatch += 1

                    // Update UI in batches for better performance
                    if cardsInBatch >= batchSize || cardCount == totalCards {
                        await MainActor.run {
                            cardsAdded = cardCount
                            addProgress = Double(cardCount) / Double(totalCards)
                        }
                        cardsInBatch = 0

                        // Small delay to show progress for small imports
                        if totalCards < 100 {
                            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                        }
                    }
                }
            }

            // Ensure final update
            await MainActor.run {
                cardsAdded = totalCards
                addProgress = 1.0
            }

            // Wait a moment to show the checkmark
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            // Dismiss everything and go back
            await MainActor.run {
                isAddingToCollection = false
                importResult = nil

                // Post notification for support banner
                NotificationCenter.default.post(
                    name: NSNotification.Name("ImportCompleted"),
                    object: nil,
                    userInfo: ["cardsCount": totalCards]
                )

                dismiss()
            }
        }
    }
}

// MARK: - Import Results View

struct ImportResultsView: View {
    let result: ImportService.ImportResult
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject var collectionManager: CollectionManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary
                    summarySection

                    // Successful Imports
                    if !result.successful.isEmpty {
                        successfulSection
                    }

                    // Failed Imports
                    if !result.failed.isEmpty {
                        failedSection
                    }

                    // Action Buttons
                    actionButtons
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("Import Results")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var summarySection: some View {
        VStack(spacing: 16) {
            // Main Stats
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(result.uniqueCardsCount)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.lorcanaGold)
                        Text("Unique Cards")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(result.totalCardsCount)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.green)
                        Text("Total Cards")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                if result.failed.count > 0 {
                    Divider()

                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("\(result.failed.count) cards failed to match")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaDark.opacity(0.8))
            )

            // Detailed Stats
            HStack(spacing: 16) {
                statBox(
                    value: result.rowsProcessed,
                    label: "Rows",
                    color: .blue
                )

                statBox(
                    value: result.successful.count,
                    label: "Matched",
                    color: .green
                )

                statBox(
                    value: result.failed.count,
                    label: "Failed",
                    color: .red
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    private func statBox(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private var successfulSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(result.successful.count) Cards Matched", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.green)

            ForEach(result.successful.prefix(10), id: \.card.id) { imported in
                HStack(spacing: 12) {
                    AsyncImage(url: imported.card.bestImageUrl()) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 55)
                    .cornerRadius(4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(imported.card.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Text("\(imported.card.setName) • \(imported.card.variant.displayName)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Text("×\(imported.quantity)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.lorcanaGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.lorcanaGold.opacity(0.2))
                        )
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                )
            }

            if result.successful.count > 10 {
                Text("+ \(result.successful.count - 10) more cards")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
        }
    }

    private var failedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(result.failed.count) Cards Failed", systemImage: "xmark.circle.fill")
                .font(.headline)
                .foregroundColor(.red)

            ForEach(result.failed.prefix(5), id: \.originalLine) { failed in
                VStack(alignment: .leading, spacing: 4) {
                    Text(failed.originalLine)
                        .font(.caption)
                        .foregroundColor(.white)

                    Text(failed.reason)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                )
            }

            if result.failed.count > 5 {
                Text("+ \(result.failed.count - 5) more failures")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !result.successful.isEmpty {
                Button(action: onConfirm) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Add \(result.totalCardsCount) Cards (\(result.successful.count) unique)")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(LorcanaButtonStyle())
            }

            Button(action: onCancel) {
                Text(result.successful.isEmpty ? "Close" : "Cancel")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}

#Preview {
    BulkImportView()
        .environmentObject(CollectionManager())
}
