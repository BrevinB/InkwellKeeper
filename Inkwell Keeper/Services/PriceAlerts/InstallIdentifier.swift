//
//  InstallIdentifier.swift
//  Inkwell Keeper
//
//  A random identifier for this installation, kept in the keychain so it
//  survives app deletion and reinstall. The price-alert backend keys devices
//  by it; it is the only credential for replacing a device's alerts, so it
//  never leaves the device except in those requests.
//

import Foundation
import Security

enum InstallIdentifier {
    private static let service = "co.brevinb.Inkwell-Keeper.install"
    private static let account = "installId"

    static var current: String {
        if let existing = read() { return existing }
        let created = UUID().uuidString.lowercased()
        save(created)
        return created
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func save(_ value: String) {
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            // Readable in the background, so a push-triggered sync can use it.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(item as CFDictionary, nil)
    }
}
