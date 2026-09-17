//
//  TradeScannerSheet.swift
//  Inkwell Keeper
//
//  Scans cards straight into one side of a trade.
//
//  Trades happen with the cards in hand, so typing names is the wrong input
//  method. This reuses the same CameraManager the Scan tab uses and stays open
//  between scans, because a trade side is usually several cards at once.
//

import SwiftUI
internal import AVFoundation

struct TradeScannerSheet: View {
    let sideTitle: String
    let onScan: (LorcanaCard) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraManager = CameraManager()
    @State private var added: [LorcanaCard] = []
    @State private var lastEventID = 0
    @State private var showingSetPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch cameraManager.permissionStatus {
                case .denied, .restricted:
                    TradeScannerPermissionNotice()
                default:
                    scannerBody
                }
            }
            .navigationTitle("Scan into \(sideTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                        .foregroundStyle(Color.lorcanaGold)
                }
            }
            .task {
                cameraManager.startSession()
            }
            .onDisappear {
                cameraManager.stopSession()
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
            // A reprint the scanner cannot pin to one set is held back rather
            // than added, so without this the scan silently does nothing.
            .onChange(of: cameraManager.pendingSetChoices) { _, choices in
                if choices != nil {
                    showingSetPicker = true
                    cameraManager.pauseAutoScan()
                } else if !showingSetPicker {
                    cameraManager.resumeAutoScan()
                }
            }
            .onChange(of: showingSetPicker) { _, isShowing in
                if !isShowing {
                    cameraManager.resumeAutoScan()
                }
            }
            .onChange(of: cameraManager.scanEventID) { _, newValue in
                guard newValue != lastEventID,
                      let entry = cameraManager.lastScannedEntry else { return }
                lastEventID = newValue
                onScan(entry.card)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    added.insert(entry.card, at: 0)
                }
            }
        }
    }

    private var scannerBody: some View {
        VStack(spacing: 0) {
            ZStack {
                CameraPreview(cameraManager: cameraManager)
                ScanOverlay(alignment: cameraManager.alignmentState)

                if cameraManager.isProcessingCard {
                    ProgressView()
                        .tint(.lorcanaGold)
                        .scaleEffect(1.4)
                }
            }
            .overlay(alignment: .topTrailing) {
                TradeFoilToggle(isOn: cameraManager.isFoilMode) {
                    cameraManager.isFoilMode.toggle()
                }
                .padding()
            }
            .frame(maxHeight: .infinity)

            TradeScanShutter(
                isDisabled: !cameraManager.isSessionRunning || cameraManager.isProcessingCard,
                isProcessing: cameraManager.isProcessingCard
            ) {
                cameraManager.capturePhoto()
            }

            TradeScanTray(cards: added)
        }
    }
}

/// Takes the shot.
///
/// CameraManager's auto-capture only fires when auto-scan has been switched on,
/// which this sheet never did — so without a shutter there was no way to scan
/// a card into a trade at all. Mirrors the Scan tab's control so the gesture is
/// the same in both places.
private struct TradeScanShutter: View {
    let isDisabled: Bool
    let isProcessing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.lorcanaGold)
                    .frame(width: 72, height: 72)

                if isProcessing {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.3)
                } else {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 62, height: 62)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 8)
            .opacity(isDisabled ? 0.6 : 1)
        }
        .buttonStyle(ShutterButtonStyle())
        .disabled(isDisabled)
        .accessibilityLabel("Capture card")
        .padding(.vertical, 12)
    }
}

/// Foils and normals are separate printings at very different prices — a
/// Legendary foil can be ten times its normal print — so the scanner has to
/// know which one is being held up.
private struct TradeFoilToggle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(isOn ? "Scanning foils" : "Scanning normals", systemImage: "sparkles", action: action)
            .font(.caption)
            .bold()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isOn ? Color.lorcanaGold.opacity(0.85) : Color.black.opacity(0.7), in: .capsule)
            .foregroundStyle(isOn ? .black : .white)
            .accessibilityLabel(isOn ? "Scanning foil cards. Tap to scan normals." : "Scanning normal cards. Tap to scan foils.")
    }
}

private struct TradeScannerPermissionNotice: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.lorcanaGold)
            Text("Camera access is off")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Turn on camera access in Settings to scan cards into a trade.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

/// Running list of what this session has added, so it is obvious the scan
/// landed without leaving the camera.
private struct TradeScanTray: View {
    let cards: [LorcanaCard]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(cards.isEmpty ? "Point at a card to add it" : "Added \(cards.count)")
                .font(.caption)
                .foregroundStyle(cards.isEmpty ? .gray : Color.lorcanaGold)
                .padding(.horizontal)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(cards, id: \.variantAwareId) { card in
                        TradeCardThumbnail(card: card, width: 44)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
            .frame(height: 64)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black)
    }
}
