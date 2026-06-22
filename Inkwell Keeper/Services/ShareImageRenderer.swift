//
//  ShareImageRenderer.swift
//  Inkwell Keeper
//
//  Turns a SwiftUI share-card view into a high-resolution UIImage using `ImageRenderer`
//  (never UIGraphicsImageRenderer), and preloads card artwork synchronously so off-screen
//  rendering captures fully-loaded images rather than empty AsyncImage placeholders.
//

import SwiftUI
import UIKit

enum ShareImageRenderer {
    /// Renders `view` to a UIImage at the given display scale. The view is expected to fully
    /// specify its own size (the share-card chrome fixes a 360×450pt canvas → 1080×1350px at 3x).
    @MainActor
    static func render(_ view: some View, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Writes `image` to a uniquely-named PNG in the temporary directory and returns its URL,
    /// suitable for handing to the system share sheet (file shares better than a raw UIImage
    /// to some targets, e.g. Files and AirDrop).
    static func temporaryFileURL(for image: UIImage, name: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let safeName = name.replacing(" ", with: "-")
        let url = URL.temporaryDirectory.appending(path: "\(safeName).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// Loads a single card image as a `UIImage`, resolving local bundle files synchronously and
    /// falling back to the shared URL cache (then the network) for remote artwork. Returns `nil`
    /// when the image can't be produced. Safe to call off the main actor.
    static func loadImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }

        if url.isFileURL {
            return UIImage(contentsOfFile: url.path)
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cached = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cached.data) {
            return image
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            return nil
        }
        URLCache.shared.storeCachedResponse(
            CachedURLResponse(response: response, data: data),
            for: request
        )
        return UIImage(data: data)
    }

    /// Preloads a set of card images keyed by an arbitrary identifier (typically the card id),
    /// loading them concurrently. Entries that fail to load are omitted from the result.
    static func preload(_ urls: [String: URL]) async -> [String: UIImage] {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for (key, url) in urls {
                group.addTask { (key, await loadImage(from: url)) }
            }

            var results: [String: UIImage] = [:]
            for await (key, image) in group {
                if let image { results[key] = image }
            }
            return results
        }
    }
}
