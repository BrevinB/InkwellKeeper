//
//  PriceAlertClient.swift
//  Inkwell Keeper
//
//  HTTP calls to the pricing backend's `/alerts` endpoints.
//

import Foundation

struct PriceAlertClient: Sendable {
    enum ClientError: Error {
        case badStatus(Int)
    }

    var baseURL = PricingService.inkwellAPIBaseURL
    var session = URLSession.shared

    func syncDevice(
        installId: String,
        _ body: PriceAlertSync.DeviceRequest
    ) async throws -> PriceAlertSync.DeviceResponse {
        let data = try await send("PUT", path: "/alerts/devices/\(installId)", body: body)
        return try PriceAlertSync.decoder.decode(PriceAlertSync.DeviceResponse.self, from: data)
    }

    func replaceHoldings(installId: String, _ holdings: [PriceAlertSync.Holding]) async throws {
        _ = try await send(
            "PUT",
            path: "/alerts/devices/\(installId)/holdings",
            body: PriceAlertSync.HoldingsRequest(holdings: holdings)
        )
    }

    func unregister(installId: String) async throws {
        _ = try await send("DELETE", path: "/alerts/devices/\(installId)", body: Optional<String>.none)
    }

    func sendTestPush(installId: String) async throws -> String {
        let data = try await send("POST", path: "/alerts/devices/\(installId)/test", body: Optional<String>.none)
        return try PriceAlertSync.decoder.decode(PriceAlertSync.TestResponse.self, from: data).result
    }

    private func send(_ method: String, path: String, body: (some Encodable)?) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try PriceAlertSync.encoder.encode(body)
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            print("[PriceAlerts] HTTP \(status) for \(method) \(path.split(separator: "/").prefix(2).joined(separator: "/"))")
            throw ClientError.badStatus(status)
        }
        return data
    }
}
