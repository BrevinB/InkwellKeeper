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
    @StateObject private var cameraManager = CameraManager()
    @State private var showingManualAdd = false
    @State private var detectedCard: LorcanaCard?
    @State private var showingCardDetail = false
    @State private var showingMultiScanReview = false
    @State private var isCapturePressed = false
    @Binding var isActive: Bool  // Track if this tab is active

    var body: some View {
        navigationWrapper {
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
                            .foregroundColor(.gray)

                        Text(errorMessage)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
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
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.lorcanaGold)
                            .cornerRadius(25)
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
                            if cameraManager.isMultiScanMode, let cardName = cameraManager.lastScannedCardName {
                                VStack {
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text(cardName)
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(20)
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
        .onChange(of: cameraManager.detectedCard) { card in
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
        .onChange(of: showingCardDetail) { isShowing in
            // Resume auto-scan with buffer when modal closes
            if !isShowing && cameraManager.isAutoScanEnabled {
                // Add 2-second buffer to allow user to reposition phone
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if cameraManager.isAutoScanEnabled && !showingCardDetail {
                        cameraManager.resumeAutoScan()
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
                    .foregroundColor(.white)
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
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("Recognizing Card...")
                .foregroundColor(.white)
                .font(.headline)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
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

                        Text(cameraManager.isAutoScanPaused ? "Auto Scan Paused" : "Auto Scan Active")
                            .font(.caption)
                            .foregroundColor(.white)
                    }

                    // Show status message if available
                    if let status = cameraManager.autoScanStatus {
                        Text(status)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    } else if cameraManager.isAutoScanPaused {
                        Text("Resuming in 2 seconds...")
                            .font(.caption2)
                            .foregroundColor(.gray)
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
                                .foregroundColor(.lorcanaGold)
                        }
                        Text("Manual Add")
                            .font(.caption)
                            .foregroundColor(.lorcanaGold)
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
                                .foregroundColor(.lorcanaGold)
                        }
                        Text("Flip")
                            .font(.caption)
                            .foregroundColor(.lorcanaGold)
                    }
                }
                .disabled(!cameraManager.isSessionRunning)
            }

            // Scan mode toggles
            HStack(spacing: 16) {
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
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Multi Scan Mode")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(cameraManager.scannedCards.isEmpty
                         ? "Scan cards to build a batch"
                         : "\(cameraManager.scannedCards.count) unique card\(cameraManager.scannedCards.count == 1 ? "" : "s") scanned")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                if !cameraManager.scannedCards.isEmpty {
                    Text("Review")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.lorcanaGold)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func navigationWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            content()
        } else {
            NavigationView {
                content()
            }
        }
    }
}

// MARK: - Scan Toggle Button

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
            .foregroundColor(isActive ? .white : .lorcanaGold)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isActive ? Color.lorcanaGold.opacity(0.8) : Color.black.opacity(0.7))
            .cornerRadius(25)
        }
    }
}
