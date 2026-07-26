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
    @State private var showingFilePicker = false
    @State private var isFileImport = false
    @State private var fileName: String?
    @State private var isImporting = false
    @State private var importDone = false
    @State private var importStats = ImportService.ImportProgress()
    @State private var importResult: ImportService.ImportResult?
    @State private var showFailedDetails = false
    /// Result held while the completion overlay is up, before the user taps Done.
    @State private var pendingResult: ImportService.ImportResult?
    @State private var showingShareCard = false
    /// Format implied by the import-method button the user tapped. Header detection
    /// still wins when it's unambiguous; this breaks ties when it isn't.
    @State private var preferredFormat: ImportService.ImportFormat?
    @State private var showingOfficialAppSheet = false
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let result = importResult, !result.failed.isEmpty {
                        // Only shown after import if there were failures
                        failedImportSummary(result)
                    } else {
                        instructionsSection
                        importMethodsSection

                        if isFileImport {
                            fileInfoSection
                        } else {
                            textInputSection
                        }

                        if !importText.isEmpty {
                            processButton
                        }
                    }
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("Bulk Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isImporting {
                    importOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .animation(.easeInOut(duration: 0.3), value: isImporting)
                }
            }
            .alert(
                "Couldn't Import",
                isPresented: Binding(
                    get: { importErrorMessage != nil },
                    set: { if !$0 { importErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importErrorMessage ?? "")
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .text, .plainText, .json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showingShareCard) {
                ShareCardPresenter(
                    analyticsType: "import",
                    qrPayload: AppLinks.appStoreURLString,
                    fileName: "InkwellKeeper-Import"
                ) { _ in
                    MilestoneShareCardView(
                        milestone: .cardsImported(count: pendingResult?.totalCardsCount ?? importStats.totalCards)
                    )
                }
            }
        }
    }

    // MARK: - Import Overlay (single unified view for progress + stats)

    private var importOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.lorcanaGold.opacity(0.2))
                        .frame(width: 80, height: 80)

                    if importDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(Color.lorcanaGold)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        ProgressView()
                            .scaleEffect(1.8)
                            .tint(.lorcanaGold)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: importDone)

                // Title + progress
                VStack(spacing: 8) {
                    Text(importDone ? "Import Complete!" : "Importing...")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.white)

                    if !importDone {
                        ProgressView(value: importStats.progress)
                            .tint(.lorcanaGold)
                            .frame(width: 220)

                        Text("\(Int(importStats.progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }

                // Live stats grid
                HStack(spacing: 0) {
                    statColumn(
                        value: importStats.totalCards,
                        label: "Total",
                        color: Color.lorcanaGold
                    )

                    Divider()
                        .frame(height: 40)
                        .background(Color.gray.opacity(0.3))

                    statColumn(
                        value: importStats.uniqueCards,
                        label: "Unique",
                        color: .white
                    )

                    Divider()
                        .frame(height: 40)
                        .background(Color.gray.opacity(0.3))

                    statColumn(
                        value: importStats.normalCards,
                        label: "Normal",
                        color: .blue
                    )

                    Divider()
                        .frame(height: 40)
                        .background(Color.gray.opacity(0.3))

                    statColumn(
                        value: importStats.foilCards,
                        label: "Foil",
                        color: .purple
                    )
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )

                if importStats.failedCards > 0 {
                    Label("\(importStats.failedCards) failed", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if importDone {
                    HStack(spacing: 12) {
                        Button("Share", systemImage: "square.and.arrow.up") {
                            showingShareCard = true
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.lorcanaGold)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.lorcanaGold, lineWidth: 1.5)
                        )
                        .buttonStyle(.plain)

                        Button("Done", systemImage: "checkmark") {
                            finishImport()
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(LorcanaButtonStyle())
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: importDone)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.lorcanaDark)
                    .shadow(color: .black.opacity(0.5), radius: 20)
            )
            .padding(.horizontal, 24)
        }
    }

    private func statColumn(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .bold()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: value)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Failed Import Summary (only shown if there were failures)

    private func failedImportSummary(_ result: ImportService.ImportResult) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)

                Text("\(result.totalCardsCount) cards imported")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            DisclosureGroup(isExpanded: $showFailedDetails) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(result.failed.prefix(10), id: \.originalLine) { failed in
                        Text(failed.reason)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }

                    if result.failed.count > 10 {
                        Text("+ \(result.failed.count - 10) more")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("\(result.failed.count) cards couldn't be matched", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaDark.opacity(0.6))
            )

            Button("Done", systemImage: "checkmark.circle.fill") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ImportCompleted"),
                    object: nil,
                    userInfo: ["cardsCount": result.totalCardsCount]
                )
                dismiss()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .buttonStyle(LorcanaButtonStyle())
        }
    }

    // MARK: - View Components

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How to Import", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.lorcanaGold)

            VStack(alignment: .leading, spacing: 6) {
                Text("Supported Formats:")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(Color.lorcanaGold)

                Text("• Dreamborn.ink CSV export (automatic)")
                    .font(.caption2)
                    .foregroundStyle(.gray)

                Text("• Collectr CSV export (automatic)")
                    .font(.caption2)
                    .foregroundStyle(.gray)

                Text("• Official Lorcana app backup file (automatic)")
                    .font(.caption2)
                    .foregroundStyle(.gray)

                Text("• Text list: One card per line")
                    .font(.caption2)
                    .foregroundStyle(.gray)

                Text("  e.g. 2x Mickey Mouse - Brave Little Tailor")
                    .font(.caption2)
                    .foregroundStyle(.gray.opacity(0.8))
                    .padding(.leading, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    private var importMethodsSection: some View {
        VStack(spacing: 12) {
            Text("Choose Import Method")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ImportMethodButton(title: "Dreamborn CSV", systemImage: "arrow.down.doc.fill") {
                    preferredFormat = .dreamborn
                    showingFilePicker = true
                }

                ImportMethodButton(title: "Collectr CSV", systemImage: "arrow.down.doc.fill") {
                    preferredFormat = .collectr
                    showingFilePicker = true
                }
            }

            ImportMethodButton(title: "Official Lorcana App", systemImage: "arrow.down.app.fill") {
                showingOfficialAppSheet = true
            }

            ImportMethodButton(title: "Paste Text List", systemImage: "doc.text.fill") {
                preferredFormat = nil
                if let clipboardText = UIPasteboard.general.string {
                    importText = clipboardText
                    isFileImport = false
                    fileName = nil
                }
            }
        }
        .sheet(isPresented: $showingOfficialAppSheet) {
            OfficialAppImportSheet(
                onPasteLink: { link in
                    showingOfficialAppSheet = false
                    importFromBackupLink(link)
                },
                onChooseFile: {
                    showingOfficialAppSheet = false
                    preferredFormat = nil
                    showingFilePicker = true
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    /// Download the backup JSON behind an official-app share link, then run the
    /// normal import pipeline on it.
    private func importFromBackupLink(_ link: String) {
        isImporting = true
        importDone = false
        importStats = ImportService.ImportProgress()

        Task {
            do {
                let backupText = try await ImportService.shared.fetchOfficialBackup(fromShareLink: link)
                await MainActor.run {
                    importText = backupText
                    isFileImport = true
                    fileName = "Official app backup"
                    processImport()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Imported File")
                .font(.headline)
                .foregroundStyle(.white)

            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.lorcanaGold)

                VStack(alignment: .leading, spacing: 4) {
                    if let fileName {
                        Text(fileName)
                            .font(.body)
                            .bold()
                            .foregroundStyle(.white)
                    }

                    let lineCount = importText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
                    Text("\(lineCount) lines")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Spacer()

                Button("Clear", systemImage: "xmark.circle.fill", role: .destructive) {
                    importText = ""
                    isFileImport = false
                    fileName = nil
                }
                .labelStyle(.iconOnly)
                .font(.title2)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaGold.opacity(0.1))
            )
        }
    }

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card List")
                .font(.headline)
                .foregroundStyle(.white)

            ZStack(alignment: .topLeading) {
                if importText.isEmpty {
                    Text("Paste your card list here...\n\nExamples:\n2x Mickey Mouse - Brave Little Tailor\nAriel - On Human Legs\nElsa - Snow Queen (Foil)")
                        .font(.subheadline)
                        .foregroundStyle(.gray.opacity(0.5))
                        .padding(12)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $importText)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
            }
            .background(Color.black.opacity(0.3))
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
            )

            if !importText.isEmpty {
                HStack {
                    let lineCount = importText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
                    Text("\(lineCount) lines")
                        .font(.caption)
                        .foregroundStyle(.gray)

                    Spacer()

                    Button("Clear") {
                        importText = ""
                        isFileImport = false
                        fileName = nil
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private var processButton: some View {
        Button("Import", systemImage: "square.and.arrow.down.fill", action: processImport)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .buttonStyle(LorcanaButtonStyle())
    }

    // MARK: - Logic

    /// Header detection wins when it's unambiguous; the button the user tapped
    /// breaks ties when a file has no recognizable header.
    private func resolveFormat(from text: String) -> ImportService.ImportFormat {
        let detected = detectFormat(from: text)
        guard detected == .textList, let preferredFormat else { return detected }

        // Collectr parsing needs a usable header row — if one can't be built,
        // honoring the button tap would silently import nothing.
        if preferredFormat == .collectr {
            let firstLine = text.components(separatedBy: .newlines).first ?? ""
            guard ImportService.HeaderColumnMap(headerLine: firstLine) != nil else { return detected }
        }

        return preferredFormat
    }

    private func detectFormat(from text: String) -> ImportService.ImportFormat {
        if ImportService.isOfficialBackup(text) {
            return .officialBackup
        }

        let firstLine = text.components(separatedBy: .newlines).first?.lowercased() ?? ""

        // Covers both the 7-column Dreamborn export and the nameless 4-column
        // Inklore.gg/LorcanaExporter variant
        if firstLine.contains("set number") && firstLine.contains("variant") {
            return .dreamborn
        }

        // Lorcana.gg-style dual-count export: "Normal,Foil,Name,Set,Number"
        if firstLine.contains("normal") && firstLine.contains("foil") && firstLine.contains("name") {
            return .collectr
        }

        // Collectr (and similar header-mapped exports): named columns in any order
        if firstLine.contains("product name") ||
           (firstLine.contains("name") && (firstLine.contains("variance") || firstLine.contains("printing") || firstLine.contains("market price") || firstLine.contains("price paid"))) {
            return .collectr
        }

        let earlyLines = text.components(separatedBy: .newlines).prefix(5)
        for line in earlyLines where !line.isEmpty {
            if line.range(of: #"^\d+,\d+[a-e]?,(normal|foil),\d+(,|$)"#, options: .regularExpression) != nil {
                return .dreamborn
            }
        }

        return .textList
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                importText = text
                isFileImport = true
                fileName = url.lastPathComponent
                processImport()
            } catch {
                // File read error
            }

        case .failure:
            break
        }
    }

    private func processImport() {
        isImporting = true
        importDone = false
        importStats = ImportService.ImportProgress()

        Task {
            let detectedFormat = resolveFormat(from: importText)

            let result = await ImportService.shared.importAndAdd(
                importText,
                format: detectedFormat,
                onCardMatched: { card, quantity in
                    collectionManager.addCard(card, quantity: quantity, bulkImport: true)
                },
                progressCallback: { stats in
                    self.importStats = stats
                }
            )

            // Nothing recognized at all (wrong file, unreadable header) must not
            // present as a successful import.
            guard result.totalProcessed > 0 else {
                await MainActor.run {
                    isImporting = false
                    importErrorMessage = "No Lorcana cards could be read from this file. Double-check that you picked a collection export (CSV) or an official app backup file."
                }
                return
            }

            await MainActor.run {
                collectionManager.finalizeBulkImport()
            }

            Analytics.send(.importCompleted(
                source: String(describing: detectedFormat),
                count: result.totalCardsCount
            ))

            await MainActor.run {
                importStats.progress = 1.0
                importStats.totalCards = result.totalCardsCount
                pendingResult = result
                importDone = true
            }
        }
    }

    /// Dismiss the completion overlay: straight out on success, or on to the
    /// failure summary when some lines couldn't be matched.
    private func finishImport() {
        guard let result = pendingResult else {
            dismiss()
            return
        }

        isImporting = false

        if result.failed.isEmpty {
            NotificationCenter.default.post(
                name: NSNotification.Name("ImportCompleted"),
                object: nil,
                userInfo: ["cardsCount": result.totalCardsCount]
            )
            dismiss()
        } else {
            importResult = result
        }
    }
}

/// Walks the user through getting their collection out of the official Disney Lorcana
/// app: its backup share link points at a hosted JSON we can download and import
/// directly. A file picker remains as a fallback for saved backup files.
struct OfficialAppImportSheet: View {
    /// Called with the clipboard's backup link when the user taps the paste button.
    let onPasteLink: (String) -> Void
    /// Called when the user prefers to pick an already-saved backup file.
    let onChooseFile: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var clipboardEmpty = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your official app collection imports straight from its backup link — no conversion needed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 14) {
                        OfficialAppStep(number: 1, text: "In the official Lorcana app, go to Home → ⋯ → Collection backup → Backup now.")
                        OfficialAppStep(number: 2, text: "Copy the backup link the app creates.")
                        OfficialAppStep(number: 3, text: "Come back here and tap Paste Backup Link.")
                    }

                    Button("Paste Backup Link", systemImage: "link", action: pasteLink)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(LorcanaButtonStyle())

                    if clipboardEmpty {
                        Text("No link on the clipboard — copy the backup link from the official app first.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Button("Choose Backup File Instead", systemImage: "arrow.down.doc.fill", action: onChooseFile)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.lorcanaGold)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.lorcanaGold.opacity(0.6), lineWidth: 1)
                        )
                        .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("You can also view your backup or convert it for other collection sites with the community-built LorcanaExporter tool — it inspired this feature.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Link("Open LorcanaExporter", destination: URL(string: "https://vladimir-aubrecht.github.io/LorcanaExporter/")!)
                            .font(.caption)
                            .bold()
                            .foregroundStyle(Color.lorcanaGold)
                    }
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("Official App Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func pasteLink() {
        guard let link = UIPasteboard.general.string, !link.isEmpty else {
            clipboardEmpty = true
            return
        }
        onPasteLink(link)
    }
}

/// A numbered instruction row in `OfficialAppImportSheet`.
struct OfficialAppStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline)
                .bold()
                .foregroundStyle(Color.lorcanaDark)
                .frame(width: 24, height: 24)
                .background(.lorcanaGold, in: .circle)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

/// Gold-outlined tile used for the import-method choices.
struct ImportMethodButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
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
            .foregroundStyle(Color.lorcanaGold)
    }
}

#Preview {
    BulkImportView()
        .environmentObject(CollectionManager())
}
