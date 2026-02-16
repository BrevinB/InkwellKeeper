//
//  CloudKitKeyService.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 2/11/26.
//

import Foundation
import CloudKit

enum CloudKitKeyError: LocalizedError {
    case noNetwork
    case recordNotFound
    case iCloudUnavailable
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "No network connection available."
        case .recordNotFound:
            return "API key not found in CloudKit."
        case .iCloudUnavailable:
            return "iCloud is not available on this device."
        case .unknownError(let error):
            return error.localizedDescription
        }
    }
}

class CloudKitKeyService {
    static let shared = CloudKitKeyService()

    private var cachedKeys: [String: String] = [:]

    private init() {}

    func fetchAPIKey(_ keyName: String) async throws -> String {
        if let cached = cachedKeys[keyName] {
            return cached
        }

        let container = CKContainer.default()
        print("[CloudKit] Using container: \(container.containerIdentifier ?? "nil")")
        let database = container.publicCloudDatabase

        let recordID = CKRecord.ID(recordName: keyName)

        do {
            let record = try await database.record(for: recordID)
            guard let key = record["key"] as? String, !key.isEmpty else {
                throw CloudKitKeyError.recordNotFound
            }
            cachedKeys[keyName] = key
            return key
        } catch let error as CKError {
            print("[CloudKit] CKError code: \(error.code.rawValue), description: \(error.localizedDescription)")
            switch error.code {
            case .networkUnavailable, .networkFailure:
                throw CloudKitKeyError.noNetwork
            case .unknownItem:
                throw CloudKitKeyError.recordNotFound
            case .notAuthenticated:
                throw CloudKitKeyError.iCloudUnavailable
            default:
                throw CloudKitKeyError.unknownError(error)
            }
        } catch {
            print("[CloudKit] Non-CK error: \(error)")
            throw CloudKitKeyError.unknownError(error)
        }
    }
}
