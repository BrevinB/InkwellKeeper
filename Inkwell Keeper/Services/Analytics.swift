//
//  Analytics.swift
//  Inkwell Keeper
//
//  Centralized TelemetryDeck event tracking. Every analytics signal in the app
//  flows through this enum so that event names and parameter keys stay consistent
//  and discoverable in one place.
//

import Foundation
import TelemetryDeck

/// A single, central façade over `TelemetryDeck` for the whole app.
///
/// Usage: `Analytics.send(.collectionCardAdded(rarity: "Rare", set: "TFC", foil: true))`.
/// Keeping every event behind this enum means the signal taxonomy lives in one file
/// and view code never references `TelemetryDeck` directly.
enum Analytics {

    /// All meaningful product events. Each case maps to a dot-namespaced
    /// TelemetryDeck signal name plus a typed set of parameters.
    enum Event {
        // MARK: Navigation
        case screenViewed(name: String)

        // MARK: Collection
        case collectionCardAdded(rarity: String, set: String, foil: Bool, source: String)
        case collectionCardRemoved
        case collectionQuantityChanged
        case wishlistAdded
        case wishlistRemoved

        // MARK: Scanning
        case scanStarted(mode: String)
        case scanCardRecognized
        case scanMultiConfirmed(count: Int)
        /// A capture that produced no card. Reasons: "noCard" (no card-shaped
        /// rectangle in frame), "noText" (card seen but OCR read nothing usable),
        /// "noMatch" (text read but nothing in the catalog matched).
        case scanFailed(reason: String)
        /// The user corrected a mis-scan (reveal chip or review sheet). `from`/`to`
        /// are "Card Name [Set Name]" — the pair shows what the matcher confused.
        case scanCorrected(from: String, to: String)

        // MARK: Decks
        case deckCreated(format: String)
        case deckDeleted
        case deckCardAdded
        case deckCardRemoved
        case deckImported(format: String)
        case starterDeckImported(name: String)

        // MARK: AI features
        case aiDeckGenerated(ink: String)
        case aiRulesQuestionAsked
        case rulesAssistantOpened(source: String)
        case rulesAnswerRated(helpful: Bool)

        // MARK: Monetization
        case paywallShown(source: String)
        case subscriptionPurchased(product: String)
        case tipPurchased(product: String)

        // MARK: Import / Export
        case importCompleted(source: String, count: Int)
        case exportCompleted(format: String)

        // MARK: Sharing & deep links
        /// The share preview was opened. Fires before rendering starts, so it counts intent
        /// to share rather than a usable card.
        case shareCardPresented(type: String)
        /// The share card finished rendering and the actions became tappable. `milliseconds`
        /// is the wait the user actually sat through on the "Preparing your card…" spinner.
        case shareRendered(type: String, milliseconds: Int)
        /// Rendering produced no image, so the preview showed its error state instead.
        case shareRenderFailed(type: String)
        /// The user tapped one of the share actions. `action` is "share", "save" or "copy".
        case shareActionTapped(type: String, action: String)
        /// A share that actually happened. `method` is "shareSheet" (the system sheet reported
        /// success), "save" (written to Photos) or "copy" (placed on the pasteboard).
        case shareCompleted(type: String, method: String)
        /// The preview was dismissed without any share completing. `stage` is "preparing" when
        /// the user gave up during the render and "preview" once the card was on screen —
        /// the pair splits a slow render from an unconvincing card.
        case shareDismissed(type: String, stage: String)
        case tradeConfirmed(yourCards: Int, theirCards: Int)
        case deckSharePresented
        /// A deck share that actually happened: the link activity finished or a list/link
        /// landed on the pasteboard. Deck *image* shares go through `shareCompleted` instead.
        case deckShareCompleted(method: String)
        case deepLinkOpened(type: String)

        // MARK: Lifecycle
        case onboardingStarted
        case onboardingCompleted
        case loreCounterGameStarted(players: Int, mode: String)

        /// The TelemetryDeck signal name.
        var signalName: String {
            switch self {
            case .screenViewed: "screen.viewed"
            case .collectionCardAdded: "collection.cardAdded"
            case .collectionCardRemoved: "collection.cardRemoved"
            case .collectionQuantityChanged: "collection.quantityChanged"
            case .wishlistAdded: "wishlist.added"
            case .wishlistRemoved: "wishlist.removed"
            case .scanStarted: "scan.started"
            case .scanCardRecognized: "scan.cardRecognized"
            case .scanMultiConfirmed: "scan.multiConfirmed"
            case .scanFailed: "scan.failed"
            case .scanCorrected: "scan.corrected"
            case .deckCreated: "deck.created"
            case .deckDeleted: "deck.deleted"
            case .deckCardAdded: "deck.cardAdded"
            case .deckCardRemoved: "deck.cardRemoved"
            case .deckImported: "deck.imported"
            case .starterDeckImported: "deck.starterImported"
            case .aiDeckGenerated: "ai.deckGenerated"
            case .aiRulesQuestionAsked: "ai.rulesQuestionAsked"
            case .rulesAssistantOpened: "ai.rulesAssistantOpened"
            case .rulesAnswerRated: "ai.rulesAnswerRated"
            case .paywallShown: "paywall.shown"
            case .subscriptionPurchased: "subscription.purchased"
            case .tipPurchased: "tipJar.tipPurchased"
            case .importCompleted: "import.completed"
            case .exportCompleted: "export.completed"
            case .shareCardPresented: "share.cardPresented"
            case .shareRendered: "share.rendered"
            case .shareRenderFailed: "share.renderFailed"
            case .shareActionTapped: "share.actionTapped"
            case .shareCompleted: "share.completed"
            case .shareDismissed: "share.dismissed"
            case .tradeConfirmed: "trade.confirmed"
            case .deckSharePresented: "deck.sharePresented"
            case .deckShareCompleted: "deck.shareCompleted"
            case .deepLinkOpened: "deepLink.opened"
            case .onboardingStarted: "onboarding.started"
            case .onboardingCompleted: "onboarding.completed"
            case .loreCounterGameStarted: "loreCounter.gameStarted"
            }
        }

        /// Parameters attached to the signal. TelemetryDeck requires string values.
        var parameters: [String: String] {
            switch self {
            case let .screenViewed(name):
                ["name": name]
            case let .collectionCardAdded(rarity, set, foil, source):
                ["rarity": rarity, "set": set, "foil": String(foil), "source": source]
            case let .scanStarted(mode):
                ["mode": mode]
            case let .scanMultiConfirmed(count):
                ["count": String(count)]
            case let .scanFailed(reason):
                ["reason": reason]
            case let .scanCorrected(from, to):
                ["guessedCard": from, "correctedCard": to]
            case let .starterDeckImported(name):
                ["name": name]
            case let .aiDeckGenerated(ink):
                ["ink": ink]
            case let .rulesAssistantOpened(source):
                ["source": source]
            case let .rulesAnswerRated(helpful):
                ["helpful": String(helpful)]
            case let .deckCreated(format):
                ["format": format]
            case let .deckImported(format):
                ["format": format]
            case let .paywallShown(source):
                ["source": source]
            case let .subscriptionPurchased(product):
                ["product": product]
            case let .tipPurchased(product):
                ["product": product]
            case let .importCompleted(source, count):
                ["source": source, "count": String(count)]
            case let .exportCompleted(format):
                ["format": format]
            // "type" is a reserved TelemetryDeck signal field and gets dropped
            // at ingestion, so these keys must not be named "type".
            case let .shareCardPresented(type):
                ["shareType": type]
            case let .shareRendered(type, milliseconds):
                ["shareType": type, "renderMilliseconds": String(milliseconds)]
            case let .shareRenderFailed(type):
                ["shareType": type]
            case let .shareActionTapped(type, action):
                ["shareType": type, "action": action]
            case let .shareCompleted(type, method):
                ["shareType": type, "method": method]
            case let .shareDismissed(type, stage):
                ["shareType": type, "stage": stage]
            case let .tradeConfirmed(yourCards, theirCards):
                ["yourCards": String(yourCards), "theirCards": String(theirCards)]
            case let .deckShareCompleted(method):
                ["method": method]
            case let .deepLinkOpened(type):
                ["linkType": type]
            case let .loreCounterGameStarted(players, mode):
                ["players": String(players), "mode": mode]
            default:
                [:]
            }
        }
    }

    /// Sends an event to TelemetryDeck.
    static func send(_ event: Event) {
        TelemetryDeck.signal(event.signalName, parameters: event.parameters)
    }
}

/// Elapsed-time helper for analytics duration parameters.
extension ContinuousClock.Instant {
    /// Whole milliseconds between this instant and now.
    var millisecondsElapsed: Int {
        let elapsed = ContinuousClock.now - self
        let components = elapsed.components
        return Int(components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000)
    }
}
