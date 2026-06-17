//
//  ScannerView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI
internal import AVFoundation

struct ScannerView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var cameraManager = CameraManager()
    @State private var showingManualAdd = false
    @State private var detectedCard: LorcanaCard?
    @State private var showingCardDetail = false
    @State private var showingMultiScanReview = false
    @State private var isCapturePressed = false
    @State private var showingCorrectionSearch = false
    @State private var showingSetPicker = false
    @State private var showScanDebug = true  // On-screen scan debug overlay (temporary)
    @Binding var isActive: Bool  // Track if this tab is active

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraManager.permissionStatus == .authorized && cameraManager.errorMessage == nil {
                    CameraPreview(cameraManager: cameraManager)
                        .ignoresSafeArea(.all)
                } else {
                    Color.black.ignoresSafeArea(.all)
                }

                // Capture flash effect
                if cameraManager.showCaptureFlash {
                    Color.white
                        .ignoresSafeArea(.all)
                        .opacity(0.7)
                        .animation(.easeOut(duration: 0.2), value: cameraManager.showCaptureFlash)
                }

                if let errorMessage = cameraManager.errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray)

                        Text(errorMessage)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal)

                        if cameraManager.permissionStatus == .denied {
                            Button("Open Settings") {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                            .buttonStyle(LorcanaButtonStyle())
                        }

                        // Always show manual add when camera is unavailable
                        Button(action: { showingManualAdd = true }) {
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
                } else {
                    VStack(spacing: 0) {
                        // MARK: - Top Header Bar
                        topHeaderBar

                        Spacer()

                        ZStack {
                            ScanOverlay()

                            if cameraManager.isProcessingCard {
                                processingIndicator
                            }

                            // Last scanned card toast in multi-scan mode
                            if cameraManager.isMultiScanMode, let entry = cameraManager.lastScannedEntry {
                                VStack {
                                    Spacer()
                                    HStack(spacing: 10) {
                                        // Card thumbnail
                                        AsyncImage(url: entry.card.bestImageUrl()) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(width: 32, height: 45)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                        // Card name (tappable area)
                                        Button {
                                            showingCorrectionSearch = true
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(.green)
                                                        .font(.caption)
                                                    Text(entry.card.name)
                                                        .foregroundStyle(.white)
                                                        .fontWeight(.semibold)
                                                        .font(.subheadline)
                                                        .lineLimit(1)
                                                }
                                                HStack(spacing: 6) {
                                                    Text("Tap to correct")
                                                        .font(.caption2)
                                                        .foregroundStyle(.gray)
                                                    AsyncPriceWithConfidenceView(card: entry.card, style: .inline)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityHint("Opens search to correct this card")

                                        Spacer()

                                        // Quantity stepper
                                        HStack(spacing: 6) {
                                            Button(action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    cameraManager.decrementLastScannedQuantity()
                                                }
                                            }) {
                                                Image(systemName: "minus")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(entry.quantity > 1 ? .white : .gray.opacity(0.4))
                                                    .frame(width: 24, height: 24)
                                                    .background(Color.white.opacity(entry.quantity > 1 ? 0.2 : 0.05))
                                                    .clipShape(Circle())
                                            }
                                            .disabled(entry.quantity <= 1)
                                            .accessibilityLabel("Decrease quantity")

                                            Text("\(entry.quantity)")
                                                .font(.subheadline)
                                                .bold()
                                                .foregroundStyle(.white)
                                                .frame(minWidth: 20)

                                            Button(action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    cameraManager.incrementLastScannedQuantity()
                                                }
                                            }) {
                                                Image(systemName: "plus")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 24, height: 24)
                                                    .background(Color.white.opacity(0.2))
                                                    .clipShape(Circle())
                                            }
                                            .accessibilityLabel("Increase quantity")
                                        }

                                        // Undo button
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                cameraManager.undoLastScan()
                                            }
                                        }) {
                                            Text("Undo")
                                                .font(.caption)
                                                .bold()
                                                .foregroundStyle(.lorcanaGold)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.lorcanaGold.opacity(0.2))
                                                .clipShape(.rect(cornerRadius: 12))
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.85))
                                    .clipShape(.rect(cornerRadius: 16))
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: cameraManager.lastScannedCardName)
                            }
                        }

                        Spacer()

                        // MARK: - Bottom Control Panel
                        bottomControlPanel
                    }
                }
            }
            .overlay(alignment: .top) {
                ScanDebugOverlay(text: cameraManager.lastScanDebug, isExpanded: $showScanDebug)
            }
            .navigationTitle("Scan Cards")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingManualAdd) {
            ManualAddCardView(isPresented: $showingManualAdd)
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingCardDetail) {
            if let card = detectedCard {
                AddCardModal(card: card, isPresented: $showingCardDetail, onAdd: { selectedCard, quantity in
                    for _ in 0..<quantity {
                        collectionManager.addCard(selectedCard)
                    }
                    showingCardDetail = false
                }, isWishlist: false)
                .environmentObject(collectionManager)
            }
        }
        .sheet(isPresented: $showingMultiScanReview) {
            MultiScanReviewView(cameraManager: cameraManager, isPresented: $showingMultiScanReview)
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingCorrectionSearch) {
            ScanCorrectionSearchView(cameraManager: cameraManager, isPresented: $showingCorrectionSearch)
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
                if cameraManager.isAutoScanEnabled {
                    cameraManager.pauseAutoScan()
                }
            } else if !showingSetPicker {
                // Resume auto-scan after set picker dismissed
                if cameraManager.isAutoScanEnabled {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        if cameraManager.isAutoScanEnabled && !showingSetPicker {
                            cameraManager.resumeAutoScan()
                        }
                    }
                }
            }
        }
        .onChange(of: showingSetPicker) { _, isShowing in
            if !isShowing && cameraManager.isAutoScanEnabled {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if cameraManager.isAutoScanEnabled && !showingSetPicker {
                        cameraManager.resumeAutoScan()
                    }
                }
            }
        }
        .onChange(of: cameraManager.detectedCard) { _, card in
            if let card = card {
                detectedCard = card
                showingCardDetail = true
                cameraManager.detectedCard = nil

                // Pause auto-scan while modal is open
                if cameraManager.isAutoScanEnabled {
                    cameraManager.pauseAutoScan()
                }
            }
        }
        .onChange(of: showingCardDetail) { _, isShowing in
            // Resume auto-scan with buffer when modal closes
            if !isShowing && cameraManager.isAutoScanEnabled {
                // Add 2-second buffer to allow user to reposition phone
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if cameraManager.isAutoScanEnabled && !showingCardDetail {
                        cameraManager.resumeAutoScan()
                    }
                }
            }
        }
        .onChange(of: showingCorrectionSearch) { _, isShowing in
            cameraManager.isCorrectionActive = isShowing
            if isShowing {
                cameraManager.pauseAutoScan()
            } else {
                // Clear the toast after correction sheet closes
                Task {
                    try? await Task.sleep(for: .seconds(3.5))
                    if !cameraManager.isCorrectionActive {
                        cameraManager.lastScannedCardName = nil
                        cameraManager.lastScannedEntry = nil
                    }
                }
                if cameraManager.isAutoScanEnabled {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        if cameraManager.isAutoScanEnabled && !showingCorrectionSearch {
                            cameraManager.resumeAutoScan()
                        }
                    }
                }
            }
        }
        .task(id: isActive) {
            // This runs on initial render AND whenever isActive changes
            if isActive {
                // Tab is active - start camera
                cameraManager.startSession()
            } else {
                // Tab is inactive - stop camera
                cameraManager.stopSession()
            }
        }
        .onDisappear {
            // Always stop when view disappears (app backgrounded, etc.)
            cameraManager.stopSession()
        }
    }

    // MARK: - Top Header Bar

    @ViewBuilder
    private var topHeaderBar: some View {
        if cameraManager.isMultiScanMode {
            multiScanBanner
        } else {
            HStack {
                Text("Scan Cards")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Processing Indicator

    private var processingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Recognizing Card...")
                .foregroundStyle(.white)
                .font(.headline)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Bottom Control Panel

    private var bottomControlPanel: some View {
        VStack(spacing: 20) {
            // Auto scan status indicator (integrated into panel)
            if cameraManager.isAutoScanEnabled {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(cameraManager.isAutoScanPaused ? Color.orange : Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(cameraManager.isProcessingCard ? 0.3 : 1.0)
                            .animation(.easeInOut(duration: 1).repeatForever(), value: cameraManager.isProcessingCard)
                            .accessibilityHidden(true)

                        Text(cameraManager.isAutoScanPaused ? "Auto Scan Paused" : "Auto Scan Active")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }

                    // Show status message if available
                    if let status = cameraManager.autoScanStatus {
                        Text(status)
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    } else if cameraManager.isAutoScanPaused {
                        Text("Resuming in 2 seconds...")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
            }

            HStack(spacing: 40) {
                // Manual Add button
                Button(action: { showingManualAdd = true }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 48, height: 48)
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.lorcanaGold)
                        }
                        Text("Manual Add")
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold)
                    }
                }

                // Capture button
                captureButton

                // Flip camera button
                Button(action: cameraManager.switchCamera) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 48, height: 48)
                            Image(systemName: "camera.rotate.fill")
                                .font(.title2)
                                .foregroundStyle(.lorcanaGold)
                        }
                        Text("Flip")
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold)
                    }
                }
                .disabled(!cameraManager.isSessionRunning)
            }

            // Scan mode toggles
            HStack(spacing: 12) {
                ScanToggleButton(
                    label: "Auto Scan",
                    icon: cameraManager.isAutoScanEnabled ? "timer" : "timer.slash",
                    isActive: cameraManager.isAutoScanEnabled,
                    action: cameraManager.toggleAutoScan
                )
                .disabled(!cameraManager.isSessionRunning)

                ScanToggleButton(
                    label: "Multi Scan",
                    icon: cameraManager.isMultiScanMode ? "rectangle.stack.fill" : "rectangle.stack",
                    isActive: cameraManager.isMultiScanMode,
                    action: cameraManager.toggleMultiScanMode
                )
                .disabled(!cameraManager.isSessionRunning)

                ScanToggleButton(
                    label: "Foil",
                    icon: cameraManager.isFoilMode ? "sparkles" : "sparkles",
                    isActive: cameraManager.isFoilMode,
                    action: { cameraManager.isFoilMode.toggle() }
                )
                .disabled(!cameraManager.isSessionRunning)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }

    // MARK: - Capture Button

    private var captureButton: some View {
        let isDisabled = !cameraManager.isSessionRunning || cameraManager.isProcessingCard

        return Button(action: cameraManager.capturePhoto) {
            Circle()
                .fill(Color.lorcanaGold)
                .frame(width: 80, height: 80)
                .overlay(
                    Group {
                        if cameraManager.isProcessingCard {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        } else {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 70, height: 70)
                        }
                    }
                )
                .shadow(color: .lorcanaGold.opacity(0.4), radius: 8)
                .opacity(isDisabled ? 0.5 : 1.0)
                .scaleEffect(isCapturePressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isCapturePressed)
        }
        .disabled(isDisabled)
        .accessibilityLabel("Capture card")
        .accessibilityHint("Takes a photo and scans the card")
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isCapturePressed = pressing
        }, perform: {})
    }

    // MARK: - Multi-Scan Banner

    private var multiScanBanner: some View {
        Button(action: { showingMultiScanReview = true }) {
            HStack(spacing: 12) {
                // Scanned cards count badge
                ZStack {
                    Circle()
                        .fill(Color.lorcanaGold)
                        .frame(width: 36, height: 36)
                    Text("\(cameraManager.totalScannedCount)")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.black)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Multi Scan Mode")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(cameraManager.scannedCards.isEmpty
                         ? "Scan cards to build a batch"
                         : "\(cameraManager.scannedCards.count) unique card\(cameraManager.scannedCards.count == 1 ? "" : "s") scanned")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Spacer()

                if !cameraManager.scannedCards.isEmpty {
                    Text("Review")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.lorcanaGold)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Scan Toggle Button

// MARK: - Scan Correction Search View

struct ScanCorrectionSearchView: View {
    var cameraManager: CameraManager
    @Binding var isPresented: Bool
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
                            cameraManager.replaceLastScannedCard(with: card)
                            isPresented = false
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
                        isPresented = false
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

// MARK: - Scan Debug Overlay (temporary diagnostics)

struct ScanDebugOverlay: View {
    let text: String?
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(isExpanded ? "Hide debug" : "Show debug") {
                isExpanded.toggle()
            }
            .font(.caption2.bold())
            .foregroundStyle(.yellow)

            if isExpanded {
                ScrollView {
                    Text(text ?? "No scan yet — capture a card.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 170)
                .padding(8)
                .background(.black.opacity(0.8))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
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
