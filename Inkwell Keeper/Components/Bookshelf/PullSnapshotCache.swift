//
//  PullSnapshotCache.swift
//  Inkwell Keeper
//
//  Holds pre-rendered pull faces for a handful of containers. Each one is a
//  full-screen-resolution image (a few MB), so the cache keeps only the most recent
//  dozen and, being an NSCache, empties itself when the system runs low on memory.
//

import Foundation

@MainActor
final class PullSnapshotCache {
    /// NSCache stores objects, so each snapshot rides in a box.
    private final class Entry {
        let snapshot: PullSnapshot?
        init(_ snapshot: PullSnapshot?) { self.snapshot = snapshot }
    }

    private let cache = NSCache<NSString, Entry>()

    init(limit: Int = 12) {
        cache.countLimit = limit
    }

    /// The cached snapshot for `key`, rendering (and caching) it on a miss.
    func snapshot(for key: String, render: () -> PullSnapshot?) -> PullSnapshot? {
        if let entry = cache.object(forKey: key as NSString) {
            return entry.snapshot
        }
        let snapshot = render()
        cache.setObject(Entry(snapshot), forKey: key as NSString)
        return snapshot
    }

    func contains(_ key: String) -> Bool {
        cache.object(forKey: key as NSString) != nil
    }
}
