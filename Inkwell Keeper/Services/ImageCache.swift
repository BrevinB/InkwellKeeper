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

/// Optimized AsyncImage wrapper with built-in caching
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack {
            switch phase {
            case .empty:
                placeholder()
                    .task {
                        await loadImage()
                    }
            case .success(let image):
                content(image)
            case .failure:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
    }

    private func loadImage() async {
        guard let url = url else {
            phase = .failure(URLError(.badURL))
            return
        }

        // Use optimized cache request
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            if let uiImage = UIImage(data: data) {
                phase = .success(Image(uiImage: uiImage))
            } else {
                phase = .failure(URLError(.cannotDecodeContentData))
            }
        } catch {
            phase = .failure(error)
        }
    }
}
