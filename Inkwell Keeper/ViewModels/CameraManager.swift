//
//  CameraManager.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI
internal import AVFoundation
import Vision

struct ScannedCardEntry: Identifiable {
    let id = UUID()
    var card: LorcanaCard
    var quantity: Int
    let scannedAt: Date
    var variant: CardVariant = .normal
}

@Observable
@MainActor
class CameraManager: NSObject {
    var isSessionRunning = false
    var detectedCard: LorcanaCard?
    var permissionStatus: AVAuthorizationStatus = .notDetermined
    var errorMessage: String?
    var isProcessingCard = false
    var showCaptureFlash = false
    var isAutoScanEnabled = false
    var isAutoScanPaused = false
    var autoScanStatus: String? = nil
    // Multi-scan (batch) is the only mode — scans always accumulate into the tray.
    var isMultiScanMode = true
    var scannedCards: [ScannedCardEntry] = []
    var lastScannedCardName: String? = nil
    var lastScannedEntry: ScannedCardEntry? = nil
    var isFoilMode = false
    var isCorrectionActive = false
    // Set disambiguation — when scanner can't determine which set a reprint belongs to
    var pendingSetChoices: [LorcanaCard]? = nil

    // Bumped on each successful multi-scan add; drives the center-reveal animation.
    var scanEventID = 0

    // Lowercase words allowed inside an otherwise Title-Case card subtitle (e.g.
    // "Snowman of Action", "Shaman of the Savanna") when extracting names from OCR.
    nonisolated static let subnameConnectorWords: Set<String> = [
        "of", "the", "and", "in", "on", "to", "a", "an", "for", "from", "with", "at", "by"
    ]

    // Live framing guidance from the continuous video feed.
    enum CardAlignment: Equatable {
        case searching   // no card-like rectangle in view
        case detected    // a card is visible but not well-framed
        case aligned     // a card fills the frame and is centered

        /// Ordering used for smoothing: higher = better framing.
        nonisolated var rank: Int {
            switch self {
            case .searching: return 0
            case .detected: return 1
            case .aligned: return 2
            }
        }
    }
    var alignmentState: CardAlignment = .searching

    @ObservationIgnored private let captureSession = AVCaptureSession()
    @ObservationIgnored private var currentDevice: AVCaptureDevice?
    @ObservationIgnored private let captureOutput = AVCapturePhotoOutput()
    @ObservationIgnored private let videoOutput = AVCaptureVideoDataOutput()
    @ObservationIgnored private let videoAnalysisQueue = DispatchQueue(
        label: "co.brevinb.inkwellkeeper.cardAlignment", qos: .userInitiated)
    // Accessed only on videoAnalysisQueue (serial), so unsynchronized access is safe.
    @ObservationIgnored nonisolated(unsafe) private var lastAlignmentAnalysis: CFAbsoluteTime = 0
    @ObservationIgnored nonisolated(unsafe) private var smoothedAlignment: CardAlignment = .searching
    @ObservationIgnored nonisolated(unsafe) private var alignmentDowngradeStreak = 0
    let previewLayer: AVCaptureVideoPreviewLayer?

    @ObservationIgnored private var lastSuccessfulScanTime: Date?
    // Auto-capture re-arms only after a card leaves the frame (see maybeAutoCapture).
    @ObservationIgnored private var armedForAutoCapture = true
    
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
    }

    func startSession() {
        guard permissionStatus == .authorized else { return }

        // Starting the session blocks, so run it off the main actor.
        let session = captureSession
        Task.detached(priority: .userInitiated) {
            if !session.isRunning {
                session.startRunning()
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isSessionRunning = session.isRunning
                self.armedForAutoCapture = true
            }
        }
    }

    func stopSession() {
        let session = captureSession
        Task.detached(priority: .userInitiated) {
            if session.isRunning {
                session.stopRunning()
            }
            await MainActor.run { [weak self] in
                self?.isSessionRunning = false
                self?.alignmentState = .searching
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
                Task { @MainActor in
                    guard let self else { return }
                    self.permissionStatus = granted ? .authorized : .denied
                    if granted {
                        self.setupCamera()
                    } else {
                        self.errorMessage = "Camera access is required to scan cards"
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

            // Optional live-framing analysis. If the session can't take a second output,
            // we simply skip alignment guidance — scanning still works normally.
            if captureSession.canAddOutput(videoOutput) {
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.setSampleBufferDelegate(self, queue: videoAnalysisQueue)
                captureSession.addOutput(videoOutput)
            }

            previewLayer?.videoGravity = .resizeAspectFill

            captureSession.commitConfiguration()

            // Keep the camera continuously focusing/exposing so it re-focuses on each
            // new card instead of locking after the first one.
            configureContinuousFocus(captureDevice)

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

        Analytics.send(.scanStarted(mode: isMultiScanMode ? "multi" : "manual"))

        // Hide flash after brief moment
        Task {
            try? await Task.sleep(for: .seconds(0.2))
            showCaptureFlash = false
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

    /// Configure the device for continuous autofocus/exposure tuned for scanning cards
    /// up close, so focus tracks each new card rather than locking after the first.
    private func configureContinuousFocus(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }
            // Cards are held close to the lens — don't bias focus to far subjects.
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .none
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }

            device.unlockForConfiguration()
        } catch {
            // Handle error silently
        }
    }

    func focusOnPoint(_ point: CGPoint) {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()

            // Bias focus/exposure to the tapped point but keep CONTINUOUS modes so it
            // doesn't lock — the next card still re-focuses automatically.
            if device.isFocusPointOfInterestSupported,
               device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .continuousAutoFocus
            }

            if device.isExposurePointOfInterestSupported,
               device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
        } catch {
            // Handle error silently
        }
    }
    
    /// Auto-capture is driven by live alignment (see `updateAlignment`), not a timer:
    /// a card is captured the moment it snaps into the frame, and re-arms only after
    /// the card leaves — so a card sitting in view is captured once, not repeatedly.
    func toggleAutoScan() {
        isAutoScanEnabled.toggle()
        armedForAutoCapture = true
    }

    func pauseAutoScan() {
        isAutoScanPaused = true
    }

    func resumeAutoScan() {
        isAutoScanPaused = false
        armedForAutoCapture = true
    }

    /// Capture automatically when a freshly-framed card aligns, if auto-capture is on.
    private func maybeAutoCapture() {
        guard isAutoScanEnabled, !isAutoScanPaused, !isProcessingCard, armedForAutoCapture else { return }
        // Debounce so a brief alignment flicker can't double-fire.
        if let last = lastSuccessfulScanTime, Date().timeIntervalSince(last) < 1.0 { return }
        armedForAutoCapture = false
        capturePhoto()
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
        // Match the variant too — otherwise re-scanning the normal version of a card
        // already in the tray as foil returns the earlier foil entry, and the reveal
        // chip shows the wrong variant.
        lastScannedEntry = scannedCards.first(where: { $0.card.name == card.name && $0.card.setName == card.setName && $0.variant == variant })
        scanEventID += 1  // Trigger the center-reveal animation

        // Haptic feedback for successful scan
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        // Clear the last scanned info after a moment (longer to allow undo/correction)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.5))
            guard let self, !self.isCorrectionActive else { return }
            if self.lastScannedCardName == card.name {
                self.lastScannedCardName = nil
                self.lastScannedEntry = nil
            }
        }
    }

    func incrementLastScannedQuantity() {
        guard let entry = lastScannedEntry else { return }

        if let index = scannedCards.firstIndex(where: { $0.card.name == entry.card.name && $0.card.setName == entry.card.setName && $0.variant == entry.variant }) {
            scannedCards[index].quantity += 1
            lastScannedEntry = scannedCards[index]
        }

        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }

    func decrementLastScannedQuantity() {
        guard let entry = lastScannedEntry else { return }

        if let index = scannedCards.firstIndex(where: { $0.card.name == entry.card.name && $0.card.setName == entry.card.setName && $0.variant == entry.variant }) {
            if scannedCards[index].quantity > 1 {
                scannedCards[index].quantity -= 1
                lastScannedEntry = scannedCards[index]
            }
        }

        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }

    func undoLastScan() {
        guard let entry = lastScannedEntry else { return }

        // Find the matching card in scannedCards and decrement or remove. Match the
        // variant too, so undoing a normal scan doesn't decrement a foil entry of the
        // same card sitting earlier in the tray.
        if let index = scannedCards.firstIndex(where: { $0.card.name == entry.card.name && $0.card.setName == entry.card.setName && $0.variant == entry.variant }) {
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
        let variant = entry.variant

        // Remove the wrongly scanned card (same variant as the one being corrected).
        if let index = scannedCards.firstIndex(where: { $0.card.name == entry.card.name && $0.card.setName == entry.card.setName && $0.variant == variant }) {
            if scannedCards[index].quantity > 1 {
                scannedCards[index].quantity -= 1
            } else {
                scannedCards.remove(at: index)
            }
        }

        // Add the correct card, preserving the variant of the scan being corrected.
        let newCardWithVariant = newCard.withVariant(variant)
        if let existingIndex = scannedCards.firstIndex(where: { $0.card.name == newCard.name && $0.card.setName == newCard.setName && $0.variant == variant }) {
            scannedCards[existingIndex].quantity += 1
        } else {
            scannedCards.append(ScannedCardEntry(card: newCardWithVariant, quantity: 1, scannedAt: Date(), variant: variant))
        }

        // Update toast to show the corrected card
        lastScannedCardName = newCard.name
        lastScannedEntry = scannedCards.first(where: { $0.card.name == newCard.name && $0.card.setName == newCard.setName && $0.variant == variant })

        // Haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        // Clear after delay
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.5))
            guard let self, !self.isCorrectionActive else { return }
            if self.lastScannedCardName == newCard.name {
                self.lastScannedCardName = nil
                self.lastScannedEntry = nil
            }
        }
    }

    func removeScannedCard(at index: Int) {
        guard index >= 0 && index < scannedCards.count else { return }
        scannedCards.remove(at: index)
    }

    /// Replace a mis-scanned card in the batch with the correct one, preserving its
    /// quantity and variant. Merges into an existing matching entry if present.
    func replaceScannedCard(at index: Int, with newCard: LorcanaCard) {
        guard index >= 0 && index < scannedCards.count else { return }
        let variant = scannedCards[index].variant
        let quantity = scannedCards[index].quantity

        scannedCards.remove(at: index)

        if let existing = scannedCards.firstIndex(where: {
            $0.card.name == newCard.name && $0.card.setName == newCard.setName && $0.variant == variant
        }) {
            scannedCards[existing].quantity += quantity
        } else {
            let entry = ScannedCardEntry(card: newCard.withVariant(variant),
                                         quantity: quantity, scannedAt: Date(), variant: variant)
            scannedCards.insert(entry, at: min(index, scannedCards.count))
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Task { @MainActor in
                self.errorMessage = "Failed to capture photo: \(error.localizedDescription)"
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { 
            Task { @MainActor in
                self.errorMessage = "Failed to process captured image"
            }
            return
        }

        Task { @MainActor in
            await self.processCardImage(image)
        }
    }
    
    private func processCardImage(_ image: UIImage) async {
        isProcessingCard = true

        // Normalize once: bake in orientation (upright) and downscale. Both Vision
        // requests share this image so rectangle detection no longer runs on raw,
        // possibly-rotated pixels while OCR runs on an upright copy.
        let normalizedImage = image.uprightScaled(to: 1200)

        // Run rectangle detection and text recognition concurrently.
        // These helpers are nonisolated, so they execute off the main actor.
        async let cardDetectedResult = detectCardInImage(normalizedImage)
        async let recognitionResult = recognizeCard(in: normalizedImage)

        let cardDetected = await cardDetectedResult
        let (recognizedCard, ocrTexts) = await recognitionResult

        isProcessingCard = false

        // Accept the card if we found one through text recognition.
        // Rectangle detection is now just a hint, not a hard requirement.
        if let card = recognizedCard {
            lastSuccessfulScanTime = Date()
            Analytics.send(.scanCardRecognized)

            // Resolve which set this card belongs to
            let resolved = resolveCardSet(card, detectedTexts: ocrTexts)

            // If pendingSetChoices was set, the UI will handle it — don't add yet
            if pendingSetChoices != nil {
                return
            }

            if isMultiScanMode {
                addToScannedCards(resolved)
            } else {
                detectedCard = resolved
            }
        } else {
            // Only show error for manual captures, not auto scan
            if !isAutoScanEnabled && !isMultiScanMode {
                errorMessage = cardDetected
                    ? "Card text not readable. Try better lighting or focus."
                    : "No card detected. Try adjusting angle or lighting."

                Task {
                    try? await Task.sleep(for: .seconds(2))
                    errorMessage = nil
                }
            } else {
                // Show brief status for auto scan / multi-scan
                autoScanStatus = cardDetected ? "Reading card text..." : "Searching for card..."
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    autoScanStatus = nil
                }
            }
        }
    }
    
    nonisolated private func recognizeCard(in image: UIImage) async -> (LorcanaCard?, [String]) {
        let detectedTexts = performTextRecognition(in: image)
        guard !detectedTexts.isEmpty else { return (nil, []) }
        let card = await searchForCard(with: detectedTexts)
        return (card, detectedTexts)
    }

    /// Run Vision text recognition and return reasonably confident text candidates.
    /// Reads `request.results` synchronously after `perform`, avoiding completion-handler
    /// callbacks (and the double-resume hazard they pose with continuations).
    nonisolated private func performTextRecognition(in image: UIImage) -> [String] {
        // Image is already upright and downscaled by processCardImage.
        guard let cgImage = image.cgImage else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate  // Use accurate mode for better text recognition
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02  // Lower threshold to catch more text (was 0.03)
        request.recognitionLanguages = ["en-US"]  // English only for better accuracy

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        guard let observations = request.results else { return [] }

        // Keep only reasonably confident text — low-confidence candidates are
        // usually OCR noise that pollutes name extraction and fallback matching.
        return observations.compactMap { observation -> String? in
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= 0.3 else { return nil }
            return candidate.string
        }
    }

    private func searchForCard(with detectedTexts: [String]) async -> LorcanaCard? {
        let setsDataManager = SetsDataManager.shared

        // Ensure data is loaded before searching — poll briefly instead of a one-shot wait.
        var attempts = 0
        while !setsDataManager.isDataLoaded && attempts < 10 {
            try? await Task.sleep(for: .milliseconds(200))
            attempts += 1
        }
        guard setsDataManager.isDataLoaded else { return nil }

        // Match by the printed card number (structured text, usually most reliable).
        let cardByNumber = findCardByNumber(from: detectedTexts)

        // Trust the number match outright ONLY when the card's name is also present in
        // the OCR text. A single misread digit in the small, low-contrast card-number
        // text otherwise returns a confidently-wrong card, so corroborate it with the
        // name before short-circuiting name-based matching.
        if let cardByNumber, cardNameMatchesDetectedText(cardByNumber, detectedTexts: detectedTexts) {
            return cardByNumber
        }

        // Name-based search.
        let potentialNames = extractCardNames(from: detectedTexts)

        for name in potentialNames {
            let results = setsDataManager.searchCards(query: name)
            if !results.isEmpty,
               let bestMatch = findBestMatch(for: name, in: results, allDetectedTexts: detectedTexts) {
                return bestMatch
            }
        }

        // Broader search with all detected text combined. This is a low-confidence
        // path, so only accept a candidate whose name actually appears in the OCR
        // text — otherwise report "not recognized" rather than guessing.
        let combinedText = detectedTexts.filter { $0.count > 2 }.joined(separator: " ")
        if !combinedText.isEmpty {
            let fallbackResults = setsDataManager.searchCards(query: combinedText)
            if let bestMatch = fallbackResults.first(where: {
                cardNameMatchesDetectedText($0, detectedTexts: detectedTexts)
            }) {
                return bestMatch
            }
        }

        // Last resort: the number match, even though its name wasn't corroborated —
        // the name text was likely unreadable, and a structured number beats nothing.
        return cardByNumber
    }
    
    nonisolated private func extractCardNames(from texts: [String]) -> [String] {
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
            
            // Identify subnames (Title Case, allowing lowercase connector words like
            // "of"/"the": "Shaman of the Savanna", "Snowman of Action", "Isolated Fortress").
            // A plain `capitalized` check rejects these because it title-cases "of" → "Of",
            // which dropped the subtitle and left only the main name to match on.
            if cleanText.contains(" ") && cleanText.count > 5 {
                let words = cleanText.components(separatedBy: " ").filter { !$0.isEmpty }
                let firstIsCapitalized = words.first?.first?.isUppercase == true
                let everyWordIsNameLike = words.allSatisfy { word in
                    word.first?.isUppercase == true || Self.subnameConnectorWords.contains(word.lowercased())
                }
                if firstIsCapitalized && everyWordIsNameLike {
                    // Exclude obvious ability names
                    if !lowercaseText.contains("ground") && !lowercaseText.contains("haven") {
                        subNames.append(cleanText)
                    }
                    continue
                }
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
    
    nonisolated private func detectCardInImage(_ image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.1
        request.maximumObservations = 10

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return false
        }

        guard let observations = request.results else { return false }

        // Check if we found any rectangles that could be cards
        let cardLikeRectangles = observations.filter { observation in
            // Cards typically have an aspect ratio around 2.5:3.5 (0.714)
            let aspectRatio = Float(observation.boundingBox.width / observation.boundingBox.height)
            let isCardLikeRatio = aspectRatio >= cardAspectRatioMin && aspectRatio <= cardAspectRatioMax

            // Rectangle should be reasonably large in the image
            let area = Float(observation.boundingBox.width * observation.boundingBox.height)
            let isReasonableSize = area >= minimumCardArea

            // Confidence should meet our threshold
            let isConfident = observation.confidence >= cardDetectionConfidence

            return isCardLikeRatio && isReasonableSize && isConfident
        }

        return !cardLikeRectangles.isEmpty
    }
    
    nonisolated private func findBestMatch(for searchTerm: String, in cards: [LorcanaCard], allDetectedTexts: [String]) -> LorcanaCard? {
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

            // Disambiguate by scoring each candidate on how many distinctive subtitle
            // words (>3 chars) appear in the detected text, then taking the single best.
            // Returning the FIRST card with any matching word picked the wrong one when a
            // word is shared: "snowman" is in both "Friendly Snowman" and "Snowman of
            // Action", so the alphabetically-earlier card always won. Scoring lets the
            // distinctive word ("action") break the tie.
            let allTextLowercased = allDetectedTexts.map { $0.lowercased() }.joined(separator: " ")

            let scored = mainNameMatches.map { card -> (card: LorcanaCard, score: Int) in
                let subName = card.name.components(separatedBy: " - ").dropFirst().first?.lowercased() ?? ""
                let score = subName.components(separatedBy: " ")
                    .filter { $0.count > 3 }
                    .reduce(0) { allTextLowercased.contains($1) ? $0 + 1 : $0 }
                return (card, score)
            }

            let bestScore = scored.map(\.score).max() ?? 0
            if bestScore > 0 {
                let leaders = scored.filter { $0.score == bestScore }
                // Only commit when one candidate clearly wins; genuine ties fall through
                // to the set-recency heuristic below rather than guessing.
                if leaders.count == 1 {
                    return leaders[0].card
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

        // No reliable match found. Returning nil lets the caller report
        // "card not recognized" instead of silently guessing a wrong card.
        return nil
    }

    /// Lightweight sanity check that a candidate card's name actually appears in the
    /// detected OCR text. Used to gate low-confidence fallback matches so the scanner
    /// reports "not recognized" rather than silently adding the wrong card.
    nonisolated private func cardNameMatchesDetectedText(_ card: LorcanaCard, detectedTexts: [String]) -> Bool {
        let haystack = detectedTexts.joined(separator: " ").lowercased()
        guard !haystack.isEmpty else { return false }

        // Corroborate on the MAIN name (the character/given name before " - "), which is
        // the discriminating part. Matching on a shared franchise word like "duck" or
        // "mouse" is NOT enough — that let misread card numbers resolve to the wrong
        // character (e.g. a Darkwing Duck scan matching "Daisy Duck" via "duck").
        let mainName = card.name.components(separatedBy: " - ").first ?? card.name
        let tokens = mainName
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }

        // Names with no significant token fall back to whole main-name containment.
        guard let distinctive = tokens.max(by: { $0.count < $1.count }) else {
            return haystack.contains(mainName.lowercased())
        }

        // Require the most distinctive (longest) token of the main name to appear —
        // usually the character's given name (e.g. "daisy", "willie", "donald").
        return haystack.contains(distinctive)
    }

    // MARK: - Set Detection from OCR

    /// Look up a card directly by its printed card number and set info.
    /// This is the most reliable identification method since card numbers are structured text.
    private func findCardByNumber(from detectedTexts: [String]) -> LorcanaCard? {
        guard let info = parseCardNumber(from: detectedTexts) else { return nil }

        let allCards = SetsDataManager.shared.getAllCards()

        // Priority 1: Match by set number (e.g., "9" → set "Fabled") + card number
        if let setNumber = info.setNumber, let matchedSet = findSetBySetNumber(setNumber) {
            if let card = allCards.first(where: { $0.setName == matchedSet.name && $0.cardNumber == info.cardNumber }) {
                return card
            }
        }

        // Priority 2: Match by card count (unique set total) + card number
        if let matchedSet = findSetByCardCount(info.setTotal) {
            if let card = allCards.first(where: { $0.setName == matchedSet.name && $0.cardNumber == info.cardNumber }) {
                return card
            }
        }

        // Priority 3: Match by card count (multiple sets share the total) + card number
        let possibleSets = findSetsByCardCount(info.setTotal)
        if possibleSets.count > 1 {
            let candidates = allCards.filter { card in
                card.cardNumber == info.cardNumber && possibleSets.contains(where: { $0.name == card.setName })
            }
            if candidates.count == 1 {
                return candidates.first
            }
        }

        return nil
    }

    /// Parsed card number info from OCR text (e.g., "207/204 · EN · 9")
    struct CardNumberInfo {
        let cardNumber: Int
        let setTotal: Int
        let setNumber: String?  // The set identifier printed on the card (e.g., "9", "P1", "D23")
    }

    /// Parse card info from OCR text. Looks for patterns like:
    /// "207/204 · EN · 9", "42/204 EN 9", "23/204 · EN · P1"
    nonisolated private func parseCardNumber(from texts: [String]) -> CardNumberInfo? {
        // First try the full pattern with set number: "X/Y · EN · Z" or "X/Y EN Z"
        // The set number can be a number or alphanumeric (P1, P2, D23, CP, Q1, etc.)
        let fullPattern = #"(\d{1,4})\s*/\s*(\d{2,4})\s*[·.\-\s]+\s*EN\s*[·.\-\s]+\s*([A-Z0-9]+)"#
        if let regex = try? NSRegularExpression(pattern: fullPattern, options: .caseInsensitive) {
            for text in texts {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    guard let numRange = Range(match.range(at: 1), in: text),
                          let totalRange = Range(match.range(at: 2), in: text),
                          let setNumRange = Range(match.range(at: 3), in: text),
                          let cardNumber = Int(text[numRange]),
                          let setTotal = Int(text[totalRange]),
                          cardNumber > 0, setTotal > 0 else {
                        continue
                    }
                    let setNumber = String(text[setNumRange])
                    return CardNumberInfo(cardNumber: cardNumber, setTotal: setTotal, setNumber: setNumber)
                }
            }
        }

        // Fallback: just the card number pattern "X/Y" without set number
        let simplePattern = #"(\d{1,4})\s*/\s*(\d{2,4})"#
        guard let regex = try? NSRegularExpression(pattern: simplePattern) else { return nil }

        for text in texts {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                guard let numRange = Range(match.range(at: 1), in: text),
                      let totalRange = Range(match.range(at: 2), in: text),
                      let cardNumber = Int(text[numRange]),
                      let setTotal = Int(text[totalRange]),
                      cardNumber > 0, setTotal > 0 else {
                    continue
                }
                return CardNumberInfo(cardNumber: cardNumber, setTotal: setTotal, setNumber: nil)
            }
        }
        return nil
    }

    /// Find a set by its printed set number (e.g., "9" → Fabled, "P1" → Promo Set 1)
    private func findSetBySetNumber(_ setNumber: String) -> LorcanaSet? {
        return SetsDataManager.shared.sets.first { $0.setNumber == setNumber }
    }

    /// Find all sets that match a given total card count
    private func findSetsByCardCount(_ total: Int) -> [LorcanaSet] {
        let sets = SetsDataManager.shared.sets
        // Exact matches first
        let exact = sets.filter { $0.cardCount == total }
        if !exact.isEmpty { return exact }
        // Allow slight tolerance (±2) for OCR misreads like "204" vs "206"
        return sets.filter { abs($0.cardCount - total) <= 2 }
    }

    /// Find a single set that matches a given total card count (only if unambiguous)
    private func findSetByCardCount(_ total: Int) -> LorcanaSet? {
        let matches = findSetsByCardCount(total)
        return matches.count == 1 ? matches.first : nil
    }

    /// Narrow a list of matched cards to the correct set using OCR-detected card number info
    private func narrowBySetInfo(cards: [LorcanaCard], detectedTexts: [String]) -> LorcanaCard? {
        guard let info = parseCardNumber(from: detectedTexts) else { return nil }

        // Priority 1: Use the set number printed on the card (most reliable)
        if let setNumber = info.setNumber, let matchedSet = findSetBySetNumber(setNumber) {
            if let card = cards.first(where: { $0.setName == matchedSet.name && $0.cardNumber == info.cardNumber }) {
                return card
            }
            if let card = cards.first(where: { $0.setName == matchedSet.name }) {
                return card
            }
        }

        // Priority 2: Try to find the set by total card count (only works for unique counts)
        if let matchedSet = findSetByCardCount(info.setTotal) {
            if let card = cards.first(where: { $0.setName == matchedSet.name && $0.cardNumber == info.cardNumber }) {
                return card
            }
            if let card = cards.first(where: { $0.setName == matchedSet.name }) {
                return card
            }
        }

        // Priority 3: Try matching by card number alone (if only one card has that number)
        let byNumber = cards.filter { $0.cardNumber == info.cardNumber }
        if byNumber.count == 1 {
            return byNumber.first
        }

        return nil
    }

    /// Resolve a matched card to the correct set version and variant (enchanted vs normal).
    /// Returns the card if determined, or sets pendingSetChoices if user needs to pick.
    private func resolveCardSet(_ card: LorcanaCard, detectedTexts: [String]) -> LorcanaCard {
        let dataManager = SetsDataManager.shared
        let allCards = dataManager.getAllCards()

        // First, check if this is an enchanted/special card via card number
        if let resolved = resolveVariant(for: card, detectedTexts: detectedTexts, allCards: allCards) {
            return resolved
        }

        // Get all normal versions of this card across sets
        let allVersions = allCards.filter {
            $0.name == card.name && $0.variant == .normal
        }

        // If only one set has this card, no disambiguation needed
        guard allVersions.count > 1 else { return card }

        // Try OCR-based set detection
        if let resolved = narrowBySetInfo(cards: allVersions, detectedTexts: detectedTexts) {
            return resolved
        }

        // Can't determine set — signal the UI to ask the user rather than guess
        // from an unreliable rarity-symbol reading.
        pendingSetChoices = allVersions

        // Return the card as-is (caller checks pendingSetChoices before using it)
        return card
    }

    /// Detect if the scanned card is an enchanted/special variant based on card number.
    /// Enchanted cards have numbers beyond the base set count (e.g., 205/204).
    private func resolveVariant(for card: LorcanaCard, detectedTexts: [String], allCards: [LorcanaCard]) -> LorcanaCard? {
        guard let info = parseCardNumber(from: detectedTexts) else { return nil }

        // Card number > set total indicates enchanted/epic/iconic variant
        guard info.cardNumber > info.setTotal else { return nil }

        let specialVariants: [CardVariant] = [.enchanted, .epic, .iconic]
        let cardMainName = card.name.components(separatedBy: " - ").first?.lowercased() ?? card.name.lowercased()

        // Priority 1: Use set number from card (e.g., "207/204 · EN · 9" → set 9 = Fabled)
        if let setNumber = info.setNumber, let matchedSet = findSetBySetNumber(setNumber) {
            // Exact name + card number
            for variant in specialVariants {
                if let specialCard = allCards.first(where: {
                    $0.name == card.name &&
                    $0.setName == matchedSet.name &&
                    $0.variant == variant &&
                    $0.cardNumber == info.cardNumber
                }) {
                    return specialCard
                }
            }
            // Main name + card number (OCR subtitle misread)
            if let specialCard = allCards.first(where: {
                $0.setName == matchedSet.name &&
                $0.cardNumber == info.cardNumber &&
                specialVariants.contains($0.variant) &&
                ($0.name.lowercased().hasPrefix(cardMainName) ||
                 ($0.name.components(separatedBy: " - ").first?.lowercased() ?? "") == cardMainName)
            }) {
                return specialCard
            }
            // Just name + set (card number OCR might be wrong)
            for variant in specialVariants {
                if let specialCard = allCards.first(where: {
                    $0.name == card.name &&
                    $0.setName == matchedSet.name &&
                    $0.variant == variant
                }) {
                    return specialCard
                }
            }
        }

        // Priority 2: Fall back to card count matching (for cards where set number wasn't read)
        let candidateSets = findSetsByCardCount(info.setTotal)
        guard !candidateSets.isEmpty else { return nil }

        // Exact name + card number across candidate sets
        for set in candidateSets {
            for variant in specialVariants {
                if let specialCard = allCards.first(where: {
                    $0.name == card.name &&
                    $0.setName == set.name &&
                    $0.variant == variant &&
                    $0.cardNumber == info.cardNumber
                }) {
                    return specialCard
                }
            }
        }

        // Main name match + card number
        for set in candidateSets {
            if let specialCard = allCards.first(where: {
                $0.setName == set.name &&
                $0.cardNumber == info.cardNumber &&
                specialVariants.contains($0.variant) &&
                ($0.name.lowercased().hasPrefix(cardMainName) ||
                 ($0.name.components(separatedBy: " - ").first?.lowercased() ?? "") == cardMainName)
            }) {
                return specialCard
            }
        }

        return nil
    }

    /// Called by the UI when the user picks a set for a pending card
    func resolveSetChoice(_ card: LorcanaCard) {
        pendingSetChoices = nil

        if isMultiScanMode {
            addToScannedCards(card)
        } else {
            detectedCard = card
        }
    }

    func dismissSetChoice() {
        pendingSetChoices = nil
    }
}

// MARK: - Live Card-Alignment Detection

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    // Mirror of the published state, read/written only on videoAnalysisQueue, so we
    // only hop to the main actor when the alignment actually changes.
    nonisolated private static let centeredTolerance = 0.30
    nonisolated private static let alignedMinArea = 0.18
    // Frames a worse reading must persist before we downgrade (acquire fast, release slow).
    nonisolated private static let downgradeFrames = 4

    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        // Throttle to ~10fps so live analysis never competes with capture or the UI.
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastAlignmentAnalysis >= 0.1 else { return }
        lastAlignmentAnalysis = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.45
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.15
        request.maximumObservations = 6
        request.minimumConfidence = 0.4

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])

        // Largest card-shaped rectangle in view, if any.
        let best = (request.results ?? [])
            .filter {
                let ratio = Float($0.boundingBox.width / $0.boundingBox.height)
                return ratio >= cardAspectRatioMin && ratio <= cardAspectRatioMax
            }
            .max { ($0.boundingBox.width * $0.boundingBox.height) < ($1.boundingBox.width * $1.boundingBox.height) }

        let rawState: CardAlignment
        if let best {
            let box = best.boundingBox
            let area = box.width * box.height
            let centered = abs(box.midX - 0.5) < Self.centeredTolerance
                && abs(box.midY - 0.5) < Self.centeredTolerance
            rawState = (area >= Self.alignedMinArea && centered) ? .aligned : .detected
        } else {
            rawState = .searching
        }

        // Asymmetric smoothing: upgrade immediately (snappy), but require several
        // consecutive worse frames before downgrading — this stops the reticle from
        // flickering between states on noisy per-frame detection.
        if rawState.rank >= smoothedAlignment.rank {
            smoothedAlignment = rawState
            alignmentDowngradeStreak = 0
        } else {
            alignmentDowngradeStreak += 1
            if alignmentDowngradeStreak >= Self.downgradeFrames {
                smoothedAlignment = rawState
                alignmentDowngradeStreak = 0
            }
        }

        let committed = smoothedAlignment
        Task { @MainActor in
            self.updateAlignment(committed)
        }
    }

    @MainActor
    func updateAlignment(_ newState: CardAlignment) {
        guard alignmentState != newState else { return }
        let wasAligned = alignmentState == .aligned
        alignmentState = newState
        if newState == .aligned {
            // Gentle nudge the moment the card snaps into good framing.
            if !wasAligned {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            maybeAutoCapture()
        } else {
            // Card left the frame (or isn't well-framed): re-arm for the next card.
            armedForAutoCapture = true
        }
    }
}

// MARK: - UIImage Extension for Performance
extension UIImage {
    /// Returns an upright (`.up` orientation) copy scaled so its longest side is at most
    /// `maxDimension`. Always redraws — even when no downscaling is needed — so the
    /// resulting `cgImage` has correct pixel orientation for Vision requests, which
    /// ignore `UIImage.imageOrientation` metadata.
    func uprightScaled(to maxDimension: CGFloat) -> UIImage {
        let size = self.size
        let longestSide = max(size.width, size.height)
        let scale = longestSide > maxDimension ? maxDimension / longestSide : 1
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
