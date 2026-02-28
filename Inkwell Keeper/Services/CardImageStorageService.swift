//
//  CardImageStorageService.swift
//  Inkwell Keeper
//

import UIKit
import Foundation

class CardImageStorageService {
    static let shared = CardImageStorageService()

    private let fileManager = FileManager.default
    private let directoryName = "UserCardImages"

    private var storageDirectory: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documentsURL.appendingPathComponent(directoryName)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    /// Save a UIImage to disk and return the file name.
    func saveImage(_ image: UIImage) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = storageDirectory.appendingPathComponent(fileName)

        // Compress to JPEG at 85% quality to balance size and quality
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }

        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("❌ [CardImageStorage] Failed to save image: \(error)")
            return nil
        }
    }

    /// Load a UIImage from disk by file name.
    func loadImage(fileName: String) -> UIImage? {
        let fileURL = storageDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// Get the full URL for an image file name.
    func imageURL(for fileName: String) -> URL {
        storageDirectory.appendingPathComponent(fileName)
    }

    /// Delete an image from disk by file name.
    func deleteImage(fileName: String) {
        let fileURL = storageDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Delete multiple images from disk.
    func deleteImages(fileNames: [String]) {
        for fileName in fileNames {
            deleteImage(fileName: fileName)
        }
    }
}
