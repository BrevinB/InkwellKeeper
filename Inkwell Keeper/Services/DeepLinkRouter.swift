//
//  DeepLinkRouter.swift
//  Inkwell Keeper
//
//  Parses incoming custom-scheme (`inkwellkeeper://…`) and Universal Link URLs into a typed
//  route the UI reacts to. Centralizing parsing keeps `ContentView` thin and makes the routing
//  rules unit-testable in isolation.
//

import Foundation
import Observation

/// A destination requested by an external link.
enum DeepLinkRoute: Equatable {
    /// Import a shared deck from its `IWK:` code.
    case deck(code: String)
    /// Open a specific card by its stable id.
    case card(id: String)
    /// Open a set's completion screen by name.
    case set(name: String)

    /// Tab index the route should select (matches `ContentView`'s tags).
    var tab: Int {
        switch self {
        case .deck: 3   // Decks
        case .card: 0   // Collection
        case .set: 2    // Sets
        }
    }

    /// Short analytics discriminator.
    var analyticsKind: String {
        switch self {
        case .deck: "deck"
        case .card: "card"
        case .set: "set"
        }
    }
}

@MainActor
@Observable
final class DeepLinkRouter {
    /// The most recent route awaiting handling by the UI. Cleared once consumed.
    var pendingRoute: DeepLinkRoute?

    /// Handles a URL from `onOpenURL` (custom scheme) — returns whether it was recognized.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let route = Self.parse(url) else { return false }
        pendingRoute = route
        Analytics.send(.deepLinkOpened(type: route.analyticsKind))
        return true
    }

    /// Handles a Universal Link delivered via `NSUserActivity`.
    @discardableResult
    func handle(_ activity: NSUserActivity) -> Bool {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL else { return false }
        return handle(url)
    }

    /// Parses either a custom-scheme URL (`inkwellkeeper://deck?code=…`) or a Universal Link
    /// (`https://inkwellkeeper.app/deck?code=…`) into a `DeepLinkRoute`. Pure and side-effect free.
    nonisolated static func parse(_ url: URL) -> DeepLinkRoute? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        // The "verb" lives in the host for the custom scheme, and in the first path segment for
        // a Universal Link.
        let verb: String
        if url.scheme == AppLinks.scheme {
            verb = url.host ?? ""
        } else if url.host == AppLinks.universalHost {
            verb = url.pathComponents.first { $0 != "/" } ?? ""
        } else {
            return nil
        }

        func query(_ name: String) -> String? {
            components?.queryItems?.first { $0.name == name }?.value
        }

        switch verb {
        case "deck":
            guard let code = query("code"), !code.isEmpty else { return nil }
            return .deck(code: code)
        case "card":
            guard let id = query("id"), !id.isEmpty else { return nil }
            return .card(id: id)
        case "set":
            guard let name = query("name"), !name.isEmpty else { return nil }
            return .set(name: name)
        default:
            return nil
        }
    }
}
