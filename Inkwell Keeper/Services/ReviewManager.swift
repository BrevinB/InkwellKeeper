//
//  ReviewManager.swift
//  Inkwell Keeper
//
//  Manages intelligent app review prompts at natural positive moments
//

import StoreKit
import UIKit

/// Tracks user engagement milestones and requests App Store reviews
/// at natural positive moments without being annoying.
///
/// Apple throttles `requestReview` to ~3 prompts per year per device,
/// so the system-level dialog will only appear occasionally even if
/// we call it more often. This manager adds its own cooldown and
/// milestone logic on top to avoid wasted calls.
@MainActor
final class ReviewManager {

    static let shared = ReviewManager()

    // MARK: - UserDefaults Keys

    private enum Key {
        static let totalCardsAdded = "ReviewManager.totalCardsAdded"
        static let lastReviewRequestDate = "ReviewManager.lastReviewRequestDate"
        static let reviewRequestCount = "ReviewManager.reviewRequestCount"
        static let appLaunchCount = "ReviewManager.appLaunchCount"
        static let lastReviewMilestone = "ReviewManager.lastReviewMilestone"
        static let hasLeftTip = "ReviewManager.hasLeftTip"
        static let multiScanSessionCount = "ReviewManager.multiScanSessionCount"
    }

    // MARK: - Configuration

    /// Minimum days between review prompts
    private let cooldownDays: Int = 45

    /// Card-count milestones that can trigger a review
    private let cardMilestones: [Int] = [10, 50, 100, 250, 500, 1000]

    /// App launch counts that can trigger a review
    private let launchMilestones: [Int] = [5, 25, 75]

    // MARK: - Initializer

    private init() {}

    // MARK: - Event Tracking

    /// Call when the app finishes launching or becomes active.
    func recordAppLaunch() {
        let count = UserDefaults.standard.integer(forKey: Key.appLaunchCount) + 1
        UserDefaults.standard.set(count, forKey: Key.appLaunchCount)

        if launchMilestones.contains(count) {
            requestReviewIfAppropriate()
        }
    }

    /// Call after a card is added to the collection. Pass the new total
    /// unique card count so the manager can check milestones.
    func recordCardAdded(totalCardCount: Int) {
        let total = UserDefaults.standard.integer(forKey: Key.totalCardsAdded) + 1
        UserDefaults.standard.set(total, forKey: Key.totalCardsAdded)

        let lastMilestone = UserDefaults.standard.integer(forKey: Key.lastReviewMilestone)

        // Find the next milestone the user just crossed
        if let milestone = cardMilestones.first(where: { $0 > lastMilestone && totalCardCount >= $0 }) {
            UserDefaults.standard.set(milestone, forKey: Key.lastReviewMilestone)
            requestReviewIfAppropriate()
        }
    }

    /// Call after the user completes a multi-scan session and adds all
    /// scanned cards to the collection.
    func recordMultiScanCompleted(cardsScanned: Int) {
        let count = UserDefaults.standard.integer(forKey: Key.multiScanSessionCount) + 1
        UserDefaults.standard.set(count, forKey: Key.multiScanSessionCount)

        // Prompt after substantial scan sessions (3+ cards) on the 2nd or 5th session
        if cardsScanned >= 3 && (count == 2 || count == 5) {
            requestReviewIfAppropriate()
        }
    }

    /// Call after the user successfully completes a tip purchase.
    func recordTipCompleted() {
        let hasLeftTipBefore = UserDefaults.standard.bool(forKey: Key.hasLeftTip)
        UserDefaults.standard.set(true, forKey: Key.hasLeftTip)

        // Only prompt on the first tip — they're already feeling generous
        if !hasLeftTipBefore {
            requestReviewIfAppropriate()
        }
    }

    // MARK: - Review Request

    /// Checks cooldown and requests a review if enough time has passed.
    private func requestReviewIfAppropriate() {
        guard isCooldownExpired() else { return }

        recordReviewRequest()

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }

        // Small delay so the prompt doesn't interrupt a transition
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    // MARK: - Helpers

    private func isCooldownExpired() -> Bool {
        guard let lastRequest = UserDefaults.standard.object(forKey: Key.lastReviewRequestDate) as? Date else {
            // Never requested before
            return true
        }

        let daysSinceLast = Calendar.current.dateComponents([.day], from: lastRequest, to: .now).day ?? 0
        return daysSinceLast >= cooldownDays
    }

    private func recordReviewRequest() {
        UserDefaults.standard.set(Date.now, forKey: Key.lastReviewRequestDate)
        let count = UserDefaults.standard.integer(forKey: Key.reviewRequestCount) + 1
        UserDefaults.standard.set(count, forKey: Key.reviewRequestCount)
    }
}
