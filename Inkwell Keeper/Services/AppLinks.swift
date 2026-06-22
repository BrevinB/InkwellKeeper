//
//  AppLinks.swift
//  Inkwell Keeper
//
//  Centralized definitions for the app's shareable links and deep-link URLs.
//  Both the share-card chrome (QR codes) and the deep-link router build URLs here
//  so the scheme, host, and App Store address live in exactly one place.
//

import Foundation

enum AppLinks {
    /// Public App Store listing, used as the universal "download the app" destination.
    static let appStoreURLString = "https://apps.apple.com/us/app/ink-well-keeper/id6754206379"

    /// Custom URL scheme registered in Info.plist (`CFBundleURLTypes`). Works immediately,
    /// without any server setup.
    static let scheme = "inkwellkeeper"

    /// Universal-link host. Lights up only once an `apple-app-site-association` file is hosted
    /// at this domain and the Associated Domains entitlement is enabled.
    static let universalHost = "inkwellkeeper.app"

    static var appStoreURL: URL? { URL(string: appStoreURLString) }

    /// Maximum length of an `IWK:` deck code we are willing to embed in a deep link / QR code.
    /// QR codes lose scannability past roughly this payload size, so longer decks fall back to
    /// the plain App Store link in shared images (the full code still travels in the share text).
    static let maxDeckCodeLengthForQR = 900

    /// Builds a custom-scheme deep link that imports a deck when opened on a device with the app.
    /// Returns `nil` if the code is too large to encode reliably in a QR code.
    static func deckDeepLink(code: String) -> URL? {
        guard code.count <= maxDeckCodeLengthForQR else { return nil }
        guard let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "\(scheme)://deck?code=\(encoded)")
    }

    /// Deep link to a specific card by its stable id.
    static func cardDeepLink(id: String) -> URL? {
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "\(scheme)://card?id=\(encoded)")
    }

    /// Deep link to a set's completion screen by set name.
    static func setDeepLink(name: String) -> URL? {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "\(scheme)://set?name=\(encoded)")
    }

    // MARK: - Universal Links (https)

    /// Builds an `https://` Universal Link for the given verb and query item.
    ///
    /// QR codes must encode `https://` URLs, never the custom scheme: a custom-scheme URL is
    /// un-openable on a device that doesn't have the app installed (the scanner has nothing to
    /// route it to). A Universal Link opens the app when installed and otherwise loads in the
    /// browser, where the hosted page redirects non-users to the App Store.
    private static func universalLink(verb: String, query name: String, value: String) -> URL? {
        guard let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://\(universalHost)/\(verb)?\(name)=\(encoded)")
    }

    /// Universal Link that imports a deck when opened. `nil` if the code is too large for a QR.
    static func deckUniversalLink(code: String) -> URL? {
        guard code.count <= maxDeckCodeLengthForQR else { return nil }
        return universalLink(verb: "deck", query: "code", value: code)
    }

    /// Universal Link to a specific card by its stable id.
    static func cardUniversalLink(id: String) -> URL? {
        universalLink(verb: "card", query: "id", value: id)
    }

    /// Universal Link to a set's completion screen by name.
    static func setUniversalLink(name: String) -> URL? {
        universalLink(verb: "set", query: "name", value: name)
    }

    // MARK: - QR payloads

    /// The string a share card's footer QR should encode for a deck: the Universal Link when it
    /// fits, otherwise the App Store link so non-users always have a path to download.
    static func deckQRPayload(code: String) -> String {
        deckUniversalLink(code: code)?.absoluteString ?? appStoreURLString
    }

    /// The string a share card's footer QR should encode for a single card.
    static func cardQRPayload(id: String) -> String {
        cardUniversalLink(id: id)?.absoluteString ?? appStoreURLString
    }

    /// The string a share card's footer QR should encode for a set.
    static func setQRPayload(name: String) -> String {
        setUniversalLink(name: name)?.absoluteString ?? appStoreURLString
    }
}
