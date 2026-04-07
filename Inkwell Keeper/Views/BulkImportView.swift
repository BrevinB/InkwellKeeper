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

    var body: some View {
        NavigationView {
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
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .text, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
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
            }
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
                Button("Dreamborn CSV", systemImage: "arrow.down.doc.fill") {
                    showingFilePicker = true
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
                .foregroundStyle(Color.lorcanaGold)

                Button("Text List", systemImage: "doc.text.fill") {
                    if let clipboardText = UIPasteboard.general.string {
                        importText = clipboardText
                        isFileImport = false
                        fileName = nil
                    }
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
                .foregroundStyle(Color.lorcanaGold)
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

    private func detectFormat(from text: String) -> ImportService.ImportFormat {
        let firstLine = text.components(separatedBy: .newlines).first?.lowercased() ?? ""

        if firstLine.contains("set number") && firstLine.contains("variant") && firstLine.contains("name") {
            return .dreamborn
        }

        if firstLine.contains("normal") && firstLine.contains("foil") && firstLine.contains("name") {
            return .dreamborn
        }

        let earlyLines = text.components(separatedBy: .newlines).prefix(5)
        for line in earlyLines where !line.isEmpty {
            if line.range(of: #"^\d+,\d+[a-e]?,(normal|foil),\d+,"#, options: .regularExpression) != nil {
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
            let detectedFormat = detectFormat(from: importText)

            let result = await ImportService.shared.importAndAdd(
                importText,
                format: detectedFormat,
                onCardMatched: { card, quantity in
                    collectionManager.addCard(card, quantity: quantity)
                },
                progressCallback: { stats in
                    self.importStats = stats
                }
            )

            await MainActor.run {
                importStats.progress = 1.0
                importStats.totalCards = result.totalCardsCount
                importDone = true
            }

            try? await Task.sleep(for: .seconds(1.5))

            await MainActor.run {
                isImporting = false
                importResult = result

                if result.failed.isEmpty {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ImportCompleted"),
                        object: nil,
                        userInfo: ["cardsCount": result.totalCardsCount]
                    )
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    BulkImportView()
        .environmentObject(CollectionManager())
}
