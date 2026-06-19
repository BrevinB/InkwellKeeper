//
//  ScannerView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI
internal import AVFoundation

// MARK: - Liquid Glass helper (iOS 26+) with material fallback

extension View {
    /// Liquid Glass background clipped to `shape` on iOS 26+, `.ultraThinMaterial`
    /// fallback on iOS 18. Used for the floating scan chrome.
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}


struct ScannerView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var cameraManager = CameraManager()
    @State private var showingManualAdd = false
    @State private var showingBatchReview = false
    @State private var showingCorrectionSearch = false
    @State private var showingSetPicker = false
    @State private var revealEntry: ScannedCardEntry?  // Reveal of the just-scanned card
    @State private var revealTask: Task<Void, Never>?
    @Binding var isActive: Bool  // Track if this tab is active

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera feed (or black when unavailable)
                if cameraManager.permissionStatus == .authorized && cameraManager.errorMessage == nil {
                    CameraPreview(cameraManager: cameraManager)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }

                // Capture flash
                if cameraManager.showCaptureFlash {
                    Color.white
                        .ignoresSafeArea()
                        .opacity(0.7)
                        .animation(.easeOut(duration: 0.2), value: cameraManager.showCaptureFlash)
                }

                if let errorMessage = cameraManager.errorMessage {
                    CameraUnavailableView(
                        message: errorMessage,
                        isDenied: cameraManager.permissionStatus == .denied,
                        onManualAdd: { showingManualAdd = true }
                    )
                } else {
                    VStack(spacing: 0) {
                        ScanTopBar(
                            isFoilOn: cameraManager.isFoilMode,
                            onToggleFoil: { cameraManager.isFoilMode.toggle() }
                        )

                        Spacer()

                        ZStack {
                            ScanOverlay(alignment: cameraManager.alignmentState)
                            if cameraManager.isProcessingCard {
                                ProcessingPill()
                            }
                        }

                        Spacer()

                        ScanControlBar(
                            cameraManager: cameraManager,
                            onManualAdd: { showingManualAdd = true },
                            onReview: { showingBatchReview = true }
                        )
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let entry = revealEntry {
                    MultiScanRevealView(entry: entry) {
                        // Tap the reveal to correct a mis-scan.
                        revealTask?.cancel()
                        withAnimation { revealEntry = nil }
                        showingCorrectionSearch = true
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 210)  // float above the control bar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .onChange(of: cameraManager.scanEventID) { _, _ in
                showScanReveal()
            }
            .onChange(of: cameraManager.isProcessingCard) { _, processing in
                // The next capture is starting — clear the previous reveal so rapid
                // scanning isn't gated on it.
                if processing { dismissReveal() }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingManualAdd) {
            ManualAddCardView(isPresented: $showingManualAdd)
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingBatchReview) {
            MultiScanReviewView(cameraManager: cameraManager, isPresented: $showingBatchReview)
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingCorrectionSearch) {
            ScanCorrectionSearchView { cameraManager.replaceLastScannedCard(with: $0) }
        }
        .sheet(isPresented: $showingSetPicker) {
            if let choices = cameraManager.pendingSetChoices {
                SetPickerSheet(cards: choices) { selected in
                    cameraManager.resolveSetChoice(selected)
                    showingSetPicker = false
                } onCancel: {
                    cameraManager.dismissSetChoice()
                    showingSetPicker = false
                }
            }
        }
        .onChange(of: cameraManager.pendingSetChoices) { _, choices in
            if choices != nil {
                showingSetPicker = true
                cameraManager.pauseAutoScan()
            } else if !showingSetPicker {
                resumeAutoScanAfterDelay { !showingSetPicker }
            }
        }
        .onChange(of: showingSetPicker) { _, isShowing in
            if !isShowing {
                resumeAutoScanAfterDelay { !showingSetPicker }
            }
        }
        .onChange(of: showingBatchReview) { _, isShowing in
            if isShowing {
                cameraManager.pauseAutoScan()
            } else {
                resumeAutoScanAfterDelay { !showingBatchReview }
            }
        }
        .onChange(of: showingCorrectionSearch) { _, isShowing in
            cameraManager.isCorrectionActive = isShowing
            if isShowing {
                cameraManager.pauseAutoScan()
            } else {
                Task {
                    try? await Task.sleep(for: .seconds(3.5))
                    if !cameraManager.isCorrectionActive {
                        cameraManager.lastScannedCardName = nil
                        cameraManager.lastScannedEntry = nil
                    }
                }
                resumeAutoScanAfterDelay { !showingCorrectionSearch }
            }
        }
        .task(id: isActive) {
            if isActive {
                cameraManager.startSession()
            } else {
                cameraManager.stopSession()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }

    /// Briefly reveal the just-scanned card large and centered, then dismiss it
    /// (it animates downward, "docking" toward the batch tray). It also gets dismissed
    /// the moment the next capture begins (see the isProcessingCard onChange), so
    /// rapid card-after-card scanning is never gated on the reveal.
    private func showScanReveal() {
        guard let entry = cameraManager.lastScannedEntry else { return }
        revealTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            revealEntry = entry
        }
        revealTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation(.easeInOut(duration: 0.3)) {
                revealEntry = nil
            }
        }
    }

    private func dismissReveal() {
        guard revealEntry != nil else { return }
        revealTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            revealEntry = nil
        }
    }

    /// Resume auto-capture a beat after a sheet closes, if still appropriate.
    private func resumeAutoScanAfterDelay(_ stillValid: @escaping () -> Bool) {
        guard cameraManager.isAutoScanEnabled else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if cameraManager.isAutoScanEnabled && stillValid() {
                cameraManager.resumeAutoScan()
            }
        }
    }
}

// MARK: - Scan Top Bar (mode/feature toggles)

struct ScanTopBar: View {
    let isFoilOn: Bool
    let onToggleFoil: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            ScanToggleButton(label: "Foil", icon: "sparkles",
                             isActive: isFoilOn, action: onToggleFoil)
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }
}

// MARK: - Processing Pill

struct ProcessingPill: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Recognizing…")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassBackground(in: .rect(cornerRadius: 16))
    }
}

// MARK: - Camera Unavailable / Permission Fallback

struct CameraUnavailableView: View {
    let message: String
    let isDenied: Bool
    let onManualAdd: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 50))
                .foregroundStyle(.gray)

            Text(message)
                .font(.title2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal)

            if isDenied {
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                .buttonStyle(LorcanaButtonStyle())
            }

            Button(action: onManualAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Manual Add Card")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.lorcanaGold)
                .clipShape(.rect(cornerRadius: 25))
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - Scan Control Bar (tray + capture + secondary actions)

struct ScanControlBar: View {
    let cameraManager: CameraManager
    let onManualAdd: () -> Void
    let onReview: () -> Void

    private var captureDisabled: Bool {
        !cameraManager.isSessionRunning || cameraManager.isProcessingCard
    }

    var body: some View {
        VStack(spacing: 16) {
            if !cameraManager.scannedCards.isEmpty {
                ScanTrayView(cameraManager: cameraManager, onReview: onReview)
            }

            HStack {
                ScanSecondaryButton(title: "Add", icon: "plus", action: onManualAdd)

                Spacer()

                Button { cameraManager.capturePhoto() } label: {
                    ZStack {
                        Circle()
                            .fill(cameraManager.isAutoScanEnabled ? Color.green : Color.lorcanaGold)
                            .frame(width: 76, height: 76)
                        if cameraManager.isProcessingCard {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.4)
                        } else {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 66, height: 66)
                            if cameraManager.isAutoScanEnabled {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .shadow(color: .black.opacity(0.3), radius: 8)
                    .opacity(captureDisabled ? 0.6 : 1)
                }
                .buttonStyle(ShutterButtonStyle())
                .disabled(captureDisabled)
                .accessibilityLabel(cameraManager.isAutoScanEnabled ? "Capture card (auto on)" : "Capture card")

                Spacer()

                ScanSecondaryButton(title: "Flip", icon: "camera.rotate") {
                    cameraManager.switchCamera()
                }
                .disabled(!cameraManager.isSessionRunning)
            }
            .padding(.horizontal, 24)
        }
        .padding(18)
        .glassBackground(in: .rect(cornerRadius: 28))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Scan Tray (batch summary)

struct ScanTrayView: View {
    let cameraManager: CameraManager
    let onReview: () -> Void

    var body: some View {
        Button(action: onReview) {
            HStack(spacing: 12) {
                ScrollView(.horizontal) {
                    HStack(spacing: -10) {
                        ForEach(cameraManager.scannedCards.suffix(8).reversed()) { entry in
                            AsyncImage(url: entry.card.bestImageUrl()) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 34, height: 47)
                            .clipShape(.rect(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.4), lineWidth: 0.5))
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: 120, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(cameraManager.totalScannedCount) card\(cameraManager.totalScannedCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.white)
                    BatchHaulView(entries: cameraManager.scannedCards)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Review")
                        .font(.subheadline)
                        .bold()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundStyle(Color.lorcanaGold)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Review \(cameraManager.totalScannedCount) scanned cards")
    }
}

// MARK: - Batch Haul Value

struct BatchHaulView: View {
    let entries: [ScannedCardEntry]

    @State private var total: Double?
    private let pricing = PricingService.shared

    var body: some View {
        Group {
            if let total {
                Text(PricingService.formatPrice(total))
                    .font(.subheadline)
                    .foregroundStyle(Color.lorcanaGold)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
        }
        .task(id: entries.map { "\($0.id)x\($0.quantity)" }.joined()) {
            var sum = 0.0
            for entry in entries {
                if let result = await pricing.getPriceWithConfidence(for: entry.card) {
                    sum += result.price * Double(entry.quantity)
                }
            }
            total = sum
        }
    }
}

// MARK: - Scan Secondary Button

struct ScanSecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .glassBackground(in: .circle)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Shutter Button Style

struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Multi-Scan Center Reveal

struct MultiScanRevealView: View {
    let entry: ScannedCardEntry
    var onCorrect: (() -> Void)?

    var body: some View {
        Button {
            onCorrect?()
        } label: {
            HStack(spacing: 10) {
                AsyncImage(url: entry.card.bestImageUrl()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 44, height: 62)
                .clipShape(.rect(cornerRadius: 5))
                .overlay(alignment: .topTrailing) {
                    if entry.variant == .foil {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(Color.lorcanaGold)
                            .padding(3)
                            .background(.black.opacity(0.6), in: .circle)
                            .padding(2)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text(entry.card.name)
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    AsyncPriceWithConfidenceView(card: entry.card, style: .inline)
                }
            }
            .padding(10)
            .frame(maxWidth: 250, alignment: .leading)
            .glassBackground(in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.lorcanaGold.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(onCorrect == nil)
        .accessibilityLabel("Scanned \(entry.card.name). Tap to correct.")
    }
}

// MARK: - Scan Toggle Button

// MARK: - Scan Correction Search View

struct ScanCorrectionSearchView: View {
    let onSelect: (LorcanaCard) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var searchText = ""
    @State private var searchResults: [LorcanaCard] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $searchText)
                    .padding()
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(200))
                            if !Task.isCancelled {
                                await MainActor.run {
                                    searchCards(query: newValue)
                                }
                            }
                        }
                    }

                if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                        Text("No cards found")
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                        Text("Search for the correct card")
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults, id: \.id) { card in
                        SimpleCardSearchRow(card: card) {
                            onSelect(card)
                            dismiss()
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Correct Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private func searchCards(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        searchResults = dataManager.searchCards(query: query)
    }
}

// MARK: - Set Picker for Reprints

struct SetPickerSheet: View {
    let cards: [LorcanaCard]
    let onSelect: (LorcanaCard) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Card preview (use first card's image)
                if let first = cards.first {
                    HStack(spacing: 12) {
                        AsyncImage(url: first.bestImageUrl()) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 70, height: 98)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(first.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("This card appears in multiple sets.")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Text("Which set is this copy from?")
                                .font(.subheadline)
                                .foregroundStyle(.lorcanaGold)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaDark.opacity(0.8))
                    )
                    .padding(.horizontal)
                }

                // Set options
                List(cards, id: \.id) { card in
                    Button(action: { onSelect(card) }) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.setName)
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                if let num = card.cardNumber {
                                    Text("Card #\(num)")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.lorcanaGold.opacity(0.6))
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Color.lorcanaDark.opacity(0.6))
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
            .background(LorcanaBackground())
            .navigationTitle("Select Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ScanToggleButton: View {
    let label: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                Text(label)
                    .font(.subheadline)
            }
            .foregroundStyle(isActive ? .white : .lorcanaGold)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isActive ? Color.lorcanaGold.opacity(0.8) : Color.black.opacity(0.7))
            .clipShape(.rect(cornerRadius: 25))
        }
    }
}
