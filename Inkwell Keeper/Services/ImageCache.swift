//
//  ImageCache.swift
//  Inkwell Keeper
//
//  Optimized image caching for card images
//

import SwiftUI
import Foundation

/// Centralized image cache manager for card images
class ImageCache {
    static let shared = ImageCache()

    private init() {
        configureURLCache()
    }

    /// Configure URLCache with optimized settings for card images
    private func configureURLCache() {
        // Configure larger cache (100MB memory, 500MB disk)
        let memoryCapacity = 100 * 1024 * 1024  // 100 MB
        let diskCapacity = 500 * 1024 * 1024    // 500 MB

        let cache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            directory: getCacheDirectory()
        )

        URLCache.shared = cache
    }

    /// Get dedicated cache directory for card images
    private func getCacheDirectory() -> URL? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let imageCacheDir = cacheDir.appendingPathComponent("CardImages", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: imageCacheDir, withIntermediateDirectories: true)

        return imageCacheDir
    }

    /// Create optimized URL request for image loading
    func createRequest(for urlString: String) -> URLRequest? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad  // Use cache first, then network
        request.timeoutInterval = 30

        return request
    }

    /// Prefetch images for cards (e.g., when loading a set)
    func prefetchImages(for cards: [LorcanaCard], priority: Float = 0.5) {
        let urls = cards.compactMap { URL(string: $0.imageUrl) }

        // Only prefetch if not already cached
        for url in urls {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)

            // Check if already in cache
            if URLCache.shared.cachedResponse(for: request) != nil {
                continue  // Skip if already cached
            }

            // Prefetch asynchronously at low priority
            Task(priority: .utility) {
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)

                    // Cache the response
                    let cachedResponse = CachedURLResponse(response: response, data: data)
                    URLCache.shared.storeCachedResponse(cachedResponse, for: request)
                } catch {
                    // Silently fail for prefetch
                }
            }
        }

    }

    /// Clear all cached images
    func clearCache() {
        URLCache.shared.removeAllCachedResponses()
    }

    /// Get cache statistics
    func getCacheStats() -> (memory: Int, disk: Int) {
        return (
            memory: URLCache.shared.currentMemoryUsage,
            disk: URLCache.shared.currentDiskUsage
        )
    }
}

/// Optimized AsyncImage wrapper with built-in caching.
///
/// Reloads whenever `url` changes. SwiftUI reuses this view when the content it sits in
/// changes but keeps the same shape (e.g. binder pockets after a page turn); keying the
/// state to the URL keeps a reused view from showing the previous card's image.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loaded: (url: URL, image: UIImage)?
    @State private var failedURL: URL?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    /// The image for the current URL only — never a leftover from a previous URL.
    private var currentImage: UIImage? {
        guard let url else { return nil }
        if let loaded, loaded.url == url { return loaded.image }
        return DecodedImageCache.shared.object(forKey: url as NSURL)
    }

    var body: some View {
        ZStack {
            if let currentImage {
                content(Image(uiImage: currentImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else { return }
        if let cached = DecodedImageCache.shared.object(forKey: url as NSURL) {
            loaded = (url, cached)
            return
        }
        guard failedURL != url else { return }

        // Use optimized cache request
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }
            if let uiImage = UIImage(data: data) {
                DecodedImageCache.shared.setObject(uiImage, forKey: url as NSURL)
                loaded = (url, uiImage)
            } else {
                failedURL = url
            }
        } catch {
            if !Task.isCancelled { failedURL = url }
        }
    }
}
