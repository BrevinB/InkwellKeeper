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
    
    var body: some View {
        NavigationView {
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
                            
                            // Auto scan toggle
                            Button(action: cameraManager.toggleAutoScan) {
                                HStack(spacing: 8) {
                                    Image(systemName: cameraManager.isAutoScanEnabled ? "timer" : "timer.slash")
                                        .font(.title2)
                                    Text(cameraManager.isAutoScanEnabled ? "Stop Auto Scan" : "Start Auto Scan")
                                        .font(.headline)
                                }
                                .foregroundColor(.lorcanaGold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(25)
                            }
                            .disabled(!cameraManager.isSessionRunning)
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
            ManualAddCardView()
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
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}
