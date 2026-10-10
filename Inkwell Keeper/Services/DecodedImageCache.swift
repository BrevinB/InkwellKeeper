//
//  DecodedImageCache.swift
//  Inkwell Keeper
//
//  Decoded card images kept in memory, so views that switch back to an image they've
//  shown recently (e.g. turning binder pages back and forth) display it instantly
//  instead of flashing a placeholder while it decodes again.
//

import UIKit

enum DecodedImageCache {
    static let shared: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 300
        return cache
    }()
}
