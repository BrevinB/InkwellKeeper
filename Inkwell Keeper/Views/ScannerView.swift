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
                    VStack {
                        // Multi-scan banner at top
                        if cameraManager.isMultiScanMode {
                            multiScanBanner
                        }

                        Spacer()

                        ZStack {
                            ScanOverlay()

                            if cameraManager.isProcessingCard {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 200, height: 80)
                                    .overlay(
                                        HStack(spacing: 12) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            Text("Recognizing Card...")
                                                .foregroundColor(.white)
                                                .font(.headline)
                                        }
                                    )
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
                                .animation(.easeInOut(duration: 0.3), value: cameraManager.lastScannedCardName)
                            }
                        }

                        Spacer()

                        VStack(spacing: 20) {
                            // Auto scan status indicator
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
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(20)
                            }

                            HStack(spacing: 40) {
                                Button(action: { showingManualAdd = true }) {
                                    VStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title)
                                        Text("Manual Add")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.lorcanaGold)
                                }

                                Button(action: cameraManager.capturePhoto) {
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
                                }
                                .disabled(!cameraManager.isSessionRunning || cameraManager.isProcessingCard)

                                Button(action: cameraManager.switchCamera) {
                                    VStack {
                                        Image(systemName: "camera.rotate.fill")
                                            .font(.title)
                                        Text("Flip")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.lorcanaGold)
                                }
                                .disabled(!cameraManager.isSessionRunning)
                            }

                            // Scan mode toggles
                            HStack(spacing: 16) {
                                // Auto scan toggle
                                Button(action: cameraManager.toggleAutoScan) {
                                    HStack(spacing: 6) {
                                        Image(systemName: cameraManager.isAutoScanEnabled ? "timer" : "timer.slash")
                                            .font(.body)
                                        Text(cameraManager.isAutoScanEnabled ? "Auto Scan" : "Auto Scan")
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(cameraManager.isAutoScanEnabled ? .white : .lorcanaGold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(cameraManager.isAutoScanEnabled ? Color.lorcanaGold.opacity(0.8) : Color.black.opacity(0.7))
                                    .cornerRadius(25)
                                }
                                .disabled(!cameraManager.isSessionRunning)

                                // Multi-scan toggle
                                Button(action: cameraManager.toggleMultiScanMode) {
                                    HStack(spacing: 6) {
                                        Image(systemName: cameraManager.isMultiScanMode ? "rectangle.stack.fill" : "rectangle.stack")
                                            .font(.body)
                                        Text("Multi Scan")
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(cameraManager.isMultiScanMode ? .white : .lorcanaGold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(cameraManager.isMultiScanMode ? Color.lorcanaGold.opacity(0.8) : Color.black.opacity(0.7))
                                    .cornerRadius(25)
                                }
                                .disabled(!cameraManager.isSessionRunning)
                            }
                        }
                        .padding(.bottom, 50)
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
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.top, 60)
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
