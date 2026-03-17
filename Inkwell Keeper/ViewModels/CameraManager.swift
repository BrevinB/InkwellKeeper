//
//  CameraManager.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI
internal import AVFoundation
import Vision
import Combine

struct ScannedCardEntry: Identifiable {
    let id = UUID()
    var card: LorcanaCard
    var quantity: Int
    let scannedAt: Date
    var variant: CardVariant = .normal
}

class CameraManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var detectedCard: LorcanaCard?
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var isProcessingCard = false
    @Published var showCaptureFlash = false
    @Published var isAutoScanEnabled = false
    @Published var isAutoScanPaused = false
    @Published var autoScanStatus: String? = nil
    // Multi-scan mode
    @Published var isMultiScanMode = false
    @Published var scannedCards: [ScannedCardEntry] = []
    @Published var lastScannedCardName: String? = nil
    @Published var lastScannedEntry: ScannedCardEntry? = nil
    @Published var isFoilMode = false
    
    private let captureSession = AVCaptureSession()
    private var currentDevice: AVCaptureDevice?
    private let captureOutput = AVCapturePhotoOutput()
    let previewLayer: AVCaptureVideoPreviewLayer?
    
    private var autoScanTimer: Timer?
    private let autoScanInterval: TimeInterval = 1.5  // Fast scanning for quick workflow
    private var lastSuccessfulScanTime: Date?
    
    // Card detection thresholds (relaxed for better detection)
    private let cardDetectionConfidence: Float = 0.5  // Lower threshold for more forgiving detection
    private let minimumCardArea: Float = 0.05  // 5% of image (was 8%, now more forgiving)
    private let cardAspectRatioMin: Float = 0.4  // More flexible for angled cards (was 0.55)
    private let cardAspectRatioMax: Float = 1.0  // Allow wider range (was 0.85)
    
    override init() {
        currentDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        super.init()
        
        checkCameraPermission()
    }
    
    deinit {
        // Stop synchronously during deallocation to avoid accessing self after dealloc
        captureSession.stopRunning()
        autoScanTimer?.invalidate()
        autoScanTimer = nil
    }

    func startSession() {
        guard permissionStatus == .authorized else { return }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isSessionRunning = self.captureSession.isRunning

                // Start auto scan if it was enabled
                if self.isAutoScanEnabled {
                    self.startAutoScan()
                }
            }
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }

            DispatchQueue.main.async { [weak self] in
                self?.isSessionRunning = false
                self?.stopAutoScan()
            }
        }
    }
    
    private func checkCameraPermission() {
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch permissionStatus {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionStatus = granted ? .authorized : .denied
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.errorMessage = "Camera access is required to scan cards"
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera access denied. Please enable camera access in Settings."
        @unknown default:
            errorMessage = "Unknown camera permission status"
        }
    }
    
    private func setupCamera() {
        guard let captureDevice = currentDevice else {
            errorMessage = "No camera available"
            return
        }
        
        captureSession.beginConfiguration()
        
        // Remove existing inputs
        captureSession.inputs.forEach { input in
            captureSession.removeInput(input)
        }
        
        // Remove existing outputs
        captureSession.outputs.forEach { output in
            captureSession.removeOutput(output)
        }
        
        do {
            // Set session preset - use photo for faster capture and better quality
            if captureSession.canSetSessionPreset(.photo) {
                captureSession.sessionPreset = .photo
            } else if captureSession.canSetSessionPreset(.high) {
                captureSession.sessionPreset = .high
            }
            
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                throw NSError(domain: "CameraError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input"])
            }
            
            if captureSession.canAddOutput(captureOutput) {
                captureSession.addOutput(captureOutput)
            } else {
                throw NSError(domain: "CameraError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add photo output"])
            }
            
            previewLayer?.videoGravity = .resizeAspectFill

            captureSession.commitConfiguration()

            // Don't auto-start the session - let the view control when to start
            // This prevents the camera from running when the tab is not active
            errorMessage = nil

        } catch {
            captureSession.commitConfiguration()
            errorMessage = "Failed to setup camera: \(error.localizedDescription)"
        }
    }
    
    func capturePhoto() {
        guard isSessionRunning && !isProcessingCard else {
            return
        }
        
        // Provide immediate feedback
        showCaptureFlash = true
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        let settings = AVCapturePhotoSettings()
        captureOutput.capturePhoto(with: settings, delegate: self)
        
        // Hide flash after brief moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.showCaptureFlash = false
        }
    }
    
    func switchCamera() {
        guard isSessionRunning else { return }

        let currentPosition = currentDevice?.position ?? .back
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            errorMessage = "Cannot switch to \(newPosition == .front ? "front" : "back") camera"
            return
        }

        currentDevice = newDevice
        setupCamera()
    }

    func focusOnPoint(_ point: CGPoint) {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
        } catch {
            // Handle error silently
        }
    }
    
    func toggleAutoScan() {
        isAutoScanEnabled.toggle()
        
        if isAutoScanEnabled {
            startAutoScan()
        } else {
            stopAutoScan()
        }
    }
    
    private func startAutoScan() {
        guard isSessionRunning && autoScanTimer == nil else { return }
        
        autoScanTimer = Timer.scheduledTimer(withTimeInterval: autoScanInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only auto-capture if we're not already processing a card
            if !self.isProcessingCard {
                // Add a small delay after successful scans to avoid rapid-fire captures of the same card
                if let lastScan = self.lastSuccessfulScanTime,
                   Date().timeIntervalSince(lastScan) < 3.0 {
                    return
                }

                self.capturePhoto()
            }
        }
    }
    
    private func stopAutoScan() {
        autoScanTimer?.invalidate()
        autoScanTimer = nil
    }

    func pauseAutoScan() {
        isAutoScanPaused = true
        autoScanTimer?.invalidate()
        autoScanTimer = nil
    }

    func resumeAutoScan() {
        isAutoScanPaused = false
        if isAutoScanEnabled && isSessionRunning {
            startAutoScan()
        }
    }

    // MARK: - Multi-Scan Mode

    func toggleMultiScanMode() {
        isMultiScanMode.toggle()
    }

    private func addToScannedCards(_ card: LorcanaCard) {
        let variant: CardVariant = isFoilMode ? .foil : .normal
        let cardWithVariant = card.withVariant(variant)

        // Check if this card+variant was already scanned
        if let index = scannedCards.firstIndex(where: { $0.card.name == card.name && $0.card.setName == card.setName && $0.variant == variant }) {
            scannedCards[index].quantity += 1
        } else {
            scannedCards.append(ScannedCardEntry(card: cardWithVariant, quantity: 1, scannedAt: Date(), variant: variant))
        }

        lastScannedCardName = card.name
        lastScannedEntry = scannedCards.first(where: { $0.card.name == card.name && $0.card.setName == card.setName })

        // Haptic feedback for successful scan
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        // Clear the last scanned info after a moment (longer to allow undo/correction)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            if self?.lastScannedCardName == card.name {
                self?.lastScannedCardName = nil
                self?.lastScannedEntry = nil
            }
        }
    }

    func undoLastScan() {
        guard let entry = lastScannedEntry else { return }

        // Find the matching card in scannedCards and decrement or remove
        if let index = scannedCards.firstIndex(where: { $0.card.name == entry.card.name && $0.card.setName == entry.card.setName }) {
            if scannedCards[index].quantity > 1 {
                scannedCards[index].quantity -= 1
            } else {
                scannedCards.remove(at: index)
            }
        }

        // Clear toast immediately
        lastScannedCardName = nil
        lastScannedEntry = nil

        // Haptic feedback for undo
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }

    func replaceLastScannedCard(with newCard: LorcanaCard) {
        guard let entry = lastScannedEntry else { return }

        // Remove the wrongly scanned card
        if let index = scannedCards.firstIndex(where: { $0.card.name == entry.card.name && $0.card.setName == entry.card.setName }) {
            if scannedCards[index].quantity > 1 {
                scannedCards[index].quantity -= 1
            } else {
                scannedCards.remove(at: index)
            }
        }

        // Add the correct card
        if let existingIndex = scannedCards.firstIndex(where: { $0.card.name == newCard.name && $0.card.setName == newCard.setName }) {
            scannedCards[existingIndex].quantity += 1
        } else {
            scannedCards.append(ScannedCardEntry(card: newCard, quantity: 1, scannedAt: Date()))
        }

        // Update toast to show the corrected card
        lastScannedCardName = newCard.name
        lastScannedEntry = scannedCards.first(where: { $0.card.name == newCard.name && $0.card.setName == newCard.setName })

        // Haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        // Clear after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            if self?.lastScannedCardName == newCard.name {
                self?.lastScannedCardName = nil
                self?.lastScannedEntry = nil
            }
        }
    }

    func removeScannedCard(at index: Int) {
        guard index >= 0 && index < scannedCards.count else { return }
        scannedCards.remove(at: index)
    }

    func updateScannedCardQuantity(at index: Int, quantity: Int) {
        guard index >= 0 && index < scannedCards.count else { return }
        if quantity <= 0 {
            scannedCards.remove(at: index)
        } else {
            scannedCards[index].quantity = quantity
        }
    }

    func updateScannedCardVariant(at index: Int, variant: CardVariant) {
        guard index >= 0 && index < scannedCards.count else { return }
        scannedCards[index].variant = variant
        scannedCards[index].card = scannedCards[index].card.withVariant(variant)
    }

    func clearScannedCards() {
        scannedCards.removeAll()
        lastScannedCardName = nil
    }

    var totalScannedCount: Int {
        scannedCards.reduce(0) { $0 + $1.quantity }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let error = error {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to capture photo: \(error.localizedDescription)"
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { 
            DispatchQueue.main.async {
                self.errorMessage = "Failed to process captured image"
            }
            return 
        }
        
        processCardImage(image)
    }
    
    private func processCardImage(_ image: UIImage) {
        isProcessingCard = true

        // Run rectangle detection and text recognition in parallel for speed
        let dispatchGroup = DispatchGroup()
        var cardDetected = false
        var recognizedCard: LorcanaCard?

        // Start rectangle detection (optional check)
        dispatchGroup.enter()
        detectCardInImage(image) { isCard in
            cardDetected = isCard
            dispatchGroup.leave()
        }

        // Start text recognition simultaneously (primary check)
        dispatchGroup.enter()
        recognizeCard(in: image) { card in
            recognizedCard = card
            dispatchGroup.leave()
        }

        // Wait for both operations to complete
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isProcessingCard = false

            // Accept the card if we found one through text recognition
            // Rectangle detection is now just a hint, not a hard requirement
            if let card = recognizedCard {
                self.lastSuccessfulScanTime = Date()

                if self.isMultiScanMode {
                    self.addToScannedCards(card)
                } else {
                    self.detectedCard = card
                }
            } else {

                // Only show error for manual captures, not auto scan
                if !self.isAutoScanEnabled && !self.isMultiScanMode {
                    if !cardDetected {
                        self.errorMessage = "No card detected. Try adjusting angle or lighting."
                    } else {
                        self.errorMessage = "Card text not readable. Try better lighting or focus."
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.errorMessage = nil
                    }
                } else {
                    // Show brief status for auto scan / multi-scan
                    self.autoScanStatus = !cardDetected ? "Searching for card..." : "Reading card text..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.autoScanStatus = nil
                    }
                }
            }
        }
    }
    
    private func recognizeCard(in image: UIImage, completion: @escaping (LorcanaCard?) -> Void) {
        // Downscale image for faster processing (max 1200px on longest side)
        let scaledImage = image.scaledDown(to: 1200)

        guard let cgImage = scaledImage.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            let detectedTexts = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }


            self.searchForCard(with: detectedTexts, completion: completion)
        }
        
        request.recognitionLevel = .accurate  // Use accurate mode for better text recognition
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02  // Lower threshold to catch more text (was 0.03)
        request.recognitionLanguages = ["en-US"]  // English only for better accuracy
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil)
            }
        }
    }
    
    private func searchForCard(with detectedTexts: [String], completion: @escaping (LorcanaCard?) -> Void) {
        let setsDataManager = SetsDataManager.shared

        Task {
            // Ensure data is loaded before searching
            if !setsDataManager.isDataLoaded {
                // Give it a moment and check again
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                if !setsDataManager.isDataLoaded {
                    completion(nil)
                    return
                }
            }

            // First, try to find card names in the detected text
            let potentialNames = extractCardNames(from: detectedTexts)

            for name in potentialNames {
                let results = setsDataManager.searchCards(query: name)

                if !results.isEmpty {
                    if let bestMatch = findBestMatch(for: name, in: results, allDetectedTexts: detectedTexts) {
                        completion(bestMatch)
                        return
                    }
                }
            }

            // If no specific searches found results, try broader search with all text combined
            let combinedText = detectedTexts.filter { $0.count > 2 }.joined(separator: " ")
            if !combinedText.isEmpty {
                let fallbackResults = setsDataManager.searchCards(query: combinedText)
                if let bestMatch = fallbackResults.first {
                    completion(bestMatch)
                    return
                }
            }

            completion(nil)
        }
    }
    
    private func extractCardNames(from texts: [String]) -> [String] {
        var mainNames: [String] = []      // ALL-CAPS main names like "RAFIKI", "SKULL ROCK"
        var subNames: [String] = []       // Capitalized subnames like "Shaman of the Savanna"
        var otherNames: [String] = []     // Other potential names
        
        for text in texts {
            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip very short or numeric-only text
            if cleanText.count < 2 || cleanText.allSatisfy({ $0.isNumber || $0.isPunctuation }) {
                continue
            }
            
            // Skip common card text that's not names (more lenient now)
            let excludeKeywords = ["characters get", "at the start", "while here", "/204", "© while here"]
            let rulesTextPatterns = ["get +", "+1 ©", " turn"]

            let lowercaseText = cleanText.lowercased()
            // Only skip if it clearly matches rules text patterns
            if excludeKeywords.contains(where: { lowercaseText == $0 }) ||
               rulesTextPatterns.contains(where: { lowercaseText.contains($0) }) {
                continue
            }
            
            // Identify main names (ALL-CAPS like "RAFIKI", "SKULL ROCK", "TRAINING DUMMY")
            if cleanText.count >= 3 && cleanText == cleanText.uppercased() {
                mainNames.append(cleanText)
                continue
            }
            
            // Identify subnames (Proper Title Case like "Shaman of the Savanna", "Isolated Fortress")
            if cleanText.contains(" ") && cleanText.capitalized == cleanText && cleanText.count > 5 {
                // Exclude obvious ability names
                if !lowercaseText.contains("ground") && !lowercaseText.contains("haven") {
                    subNames.append(cleanText)
                }
                continue
            }
            
            // Single word proper names (like "Training" from "Training Dummy")
            if cleanText.count > 3 && cleanText.first?.isUppercase == true && !cleanText.contains(" ") {
                otherNames.append(cleanText)
            }
        }
        
        // Build search queries with priority:
        // 1. Try "MainName Subname" combinations first (most specific)
        // 2. Then individual main names
        // 3. Then subnames
        // 4. Finally other names
        
        var searchQueries: [String] = []
        
        // Create MainName - Subname combinations (with proper dash format)
        for mainName in mainNames {
            for subName in subNames {
                let combinedQuery = "\(mainName) - \(subName)"
                searchQueries.append(combinedQuery)
            }
        }
        
        // Add individual main names (high priority)
        searchQueries.append(contentsOf: mainNames)
        
        // Add subnames (medium priority)
        searchQueries.append(contentsOf: subNames)
        
        // Add other names (low priority)
        searchQueries.append(contentsOf: otherNames)
        
        return searchQueries
    }
    
    private func detectCardInImage(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(false)
            return
        }
        
        let request = VNDetectRectanglesRequest { request, error in
            if let error = error {
                completion(false)
                return
            }
            
            guard let observations = request.results as? [VNRectangleObservation] else {
                completion(false)
                return
            }
            
            // Check if we found any rectangles that could be cards
            let cardLikeRectangles = observations.filter { observation in
                // Cards typically have an aspect ratio around 2.5:3.5 (0.714)
                let aspectRatio = Float(observation.boundingBox.width / observation.boundingBox.height)
                let isCardLikeRatio = aspectRatio >= self.cardAspectRatioMin && aspectRatio <= self.cardAspectRatioMax
                
                // Rectangle should be reasonably large in the image
                let area = Float(observation.boundingBox.width * observation.boundingBox.height)
                let isReasonableSize = area >= self.minimumCardArea
                
                // Confidence should meet our threshold
                let isConfident = observation.confidence >= self.cardDetectionConfidence
                
                
                return isCardLikeRatio && isReasonableSize && isConfident
            }
            
            let hasCardLikeRectangle = !cardLikeRectangles.isEmpty
            
            completion(hasCardLikeRectangle)
        }
        
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.1
        request.maximumObservations = 10
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(false)
            }
        }
    }
    
    private func findBestMatch(for searchTerm: String, in cards: [LorcanaCard], allDetectedTexts: [String]) -> LorcanaCard? {
        let lowercaseSearch = searchTerm.lowercased()

        // Look for exact matches first (highest priority)
        if let exactMatch = cards.first(where: { $0.name.lowercased() == lowercaseSearch }) {
            return exactMatch
        }

        // If search contains both main and sub name (like "MAUI - Half Shark" or "MAUI Half Shark")
        // This handles the combined main+sub name from extractCardNames
        if searchTerm.contains(" ") && searchTerm.split(separator: " ").count > 1 {
            // Handle both "MAUI - Half Shark" and "MAUI Half Shark" formats
            let parts = searchTerm.components(separatedBy: " - ")
            var possibleMainName: String
            var possibleSubName: String

            if parts.count == 2 {
                // Format: "MAUI - Half Shark"
                possibleMainName = parts[0].lowercased().trimmingCharacters(in: .whitespaces)
                possibleSubName = parts[1].lowercased().trimmingCharacters(in: .whitespaces)
            } else {
                // Format: "MAUI Half Shark" (no dash)
                let words = searchTerm.components(separatedBy: " ")
                possibleMainName = words[0].lowercased()
                possibleSubName = words.dropFirst().joined(separator: " ").lowercased()
            }

            // Priority 1: Both parts match exactly
            for card in cards {
                let cardParts = card.name.components(separatedBy: " - ")
                if cardParts.count == 2 {
                    let cardMainName = cardParts[0].lowercased().trimmingCharacters(in: .whitespaces)
                    let cardSubName = cardParts[1].lowercased().trimmingCharacters(in: .whitespaces)

                    if cardMainName == possibleMainName && cardSubName == possibleSubName {
                        return card
                    }
                }
            }

            // Priority 2: Both parts contain the search terms (for partial matches)
            for card in cards {
                let cardParts = card.name.components(separatedBy: " - ")
                if cardParts.count == 2 {
                    let cardMainName = cardParts[0].lowercased()
                    let cardSubName = cardParts[1].lowercased()

                    if cardMainName.contains(possibleMainName) && cardSubName.contains(possibleSubName) {
                        return card
                    }
                }
            }

            // Priority 3: Subname matches (for when we have subname but main name is common)
            for card in cards {
                let cardParts = card.name.components(separatedBy: " - ")
                if cardParts.count == 2 {
                    let cardSubName = cardParts[1].lowercased()

                    if cardSubName == possibleSubName || cardSubName.contains(possibleSubName) {
                        return card
                    }
                }
            }
        }

        // Priority 4: Main name exact match (for single-word searches like just "MAUI" or "RAYA")
        // When there are multiple cards with same main name, use all detected texts to disambiguate
        let mainNameMatches = cards.filter { card in
            let mainName = card.name.components(separatedBy: " - ").first?.lowercased() ?? ""
            return mainName == lowercaseSearch
        }

        if mainNameMatches.count == 1 {
            return mainNameMatches.first
        } else if mainNameMatches.count > 1 {

            // Try to disambiguate by checking if any subtitle words appear in ALL detected texts
            let allTextLowercased = allDetectedTexts.map { $0.lowercased() }.joined(separator: " ")

            for card in mainNameMatches {
                let cardParts = card.name.components(separatedBy: " - ")
                if cardParts.count == 2 {
                    let subName = cardParts[1].lowercased()
                    let subWords = subName.components(separatedBy: " ")

                    // Check if any significant word from the subtitle appears in the detected text
                    for word in subWords where word.count > 3 {  // Only check words longer than 3 chars
                        if allTextLowercased.contains(word) {
                            return card
                        }
                    }
                }
            }

            // If we can't disambiguate, prefer more recent sets (higher set number typically = newer)
            let sortedBySet = mainNameMatches.sorted { card1, card2 in
                // Sort by set name descending (newer sets typically come later alphabetically)
                return card1.setName > card2.setName
            }

            return sortedBySet.first
        }

        // Priority 5: Cards that start with the search term
        let startsWithMatches = cards.filter { $0.name.lowercased().hasPrefix(lowercaseSearch) }
        if !startsWithMatches.isEmpty {
            return startsWithMatches.first
        }

        // Priority 6: Cards that contain the search term anywhere
        let containsMatches = cards.filter { $0.name.lowercased().contains(lowercaseSearch) }
        if !containsMatches.isEmpty {
            return containsMatches.first
        }

        // Last resort: return first result
        return cards.first
    }
}

// MARK: - UIImage Extension for Performance
extension UIImage {
    func scaledDown(to maxDimension: CGFloat) -> UIImage {
        let size = self.size
        let longestSide = max(size.width, size.height)

        // If image is already smaller, return as-is
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
