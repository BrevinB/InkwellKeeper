//
//  LorcanaCardExtensions.swift
//  Inkwell Keeper
//
//  Extensions for LorcanaCard to support variant-specific images
//

import Foundation

/// Wrapper for grouping reprinted cards together
struct CardGroup: Identifiable {
    let id: String // Based on card name
    let name: String
    let cards: [LorcanaCard] // All versions of this card

    var primaryCard: LorcanaCard {
        // Return the most recent printing (highest set number)
        cards.max(by: { ($0.setName, $0.uniqueId ?? "") < ($1.setName, $1.uniqueId ?? "") }) ?? cards[0]
    }

    var isReprint: Bool {
        cards.count > 1
    }

    var setCount: Int {
        cards.count
    }

    var sets: [String] {
        cards.map { $0.setName }
    }
}

extension LorcanaCard {
    /// Get local image URL from app bundle
    /// Returns nil if local image not found
    func localImageUrl() -> URL? {
        guard let uniqueId = self.uniqueId else { return nil }

        // Map set IDs to folder names
        let setFolderMap: [String: String] = [
            "The First Chapter": "the_first_chapter",
            "Rise of the Floodborn": "rise_of_the_floodborn",
            "Into the Inklands": "into_the_inklands",
            "Ursula's Return": "ursulas_return",
            "Shimmering Skies": "shimmering_skies",
            "Azurite Sea": "azurite_sea",
            "Fabled": "fabled",
            "Archazia's Island": "archazias_island",
            "Reign of Jafar": "reign_of_jafar"
        ]

        guard let folderName = setFolderMap[setName] else { return nil }

        // Try both .png and .jpg extensions (Reign of Jafar uses .jpg, others use .png)
        let extensions = ["png", "jpg"]

        for ext in extensions {
            let filename = "\(uniqueId).\(ext)"
            if let url = Bundle.main.url(
                forResource: filename.replacingOccurrences(of: ".\(ext)", with: ""),
                withExtension: ext,
                subdirectory: "Resources/CardImages/\(folderName)"
            ) {
                return url
            }
        }

        return nil
    }

    /// Get the best available image URL - prefers local, falls back to remote
    func bestImageUrl() -> URL? {
        // Try local first
        if let localUrl = localImageUrl() {
            return localUrl
        }

        // Fall back to remote URL
        return URL(string: imageUrl)
    }

    /// Get the image URL for a specific variant
    /// Attempts to construct variant-specific URL, falls back to base image if not available
    func imageUrl(for variant: CardVariant) -> String {
        // If it's the normal variant or the card already has the right variant, use existing URL
        if variant == .normal || variant == self.variant {
            return self.imageUrl
        }

        // Try to construct variant-specific URL based on Lorcana API patterns
        // Pattern: https://lorcana-api.com/images/{card_name}/{subtitle}/{card_name}-{subtitle}-{variant}.png

        let baseUrl = self.imageUrl

        // Check if this is a Lorcana API URL
        guard baseUrl.contains("lorcana-api.com/images/") else {
            return baseUrl  // Not a Lorcana API URL, return as-is
        }

        // Try to construct variant URL
        let variantSuffix: String
        switch variant {
        case .normal:
            return baseUrl  // Already handled above
        case .foil:
            variantSuffix = "foil"
        case .borderless:
            variantSuffix = "borderless"
        case .promo:
            variantSuffix = "promo"
        case .enchanted:
            variantSuffix = "enchanted"
        }

        // Replace "-large.png" with "-{variant}-large.png" or similar patterns
        if baseUrl.hasSuffix("-large.png") {
            let withoutSuffix = baseUrl.replacingOccurrences(of: "-large.png", with: "")
            return "\(withoutSuffix)-\(variantSuffix)-large.png"
        } else if baseUrl.hasSuffix(".png") {
            let withoutSuffix = baseUrl.replacingOccurrences(of: ".png", with: "")
            return "\(withoutSuffix)-\(variantSuffix).png"
        }

        // If we can't determine the pattern, return base URL
        return baseUrl
    }

    /// Create a new card instance with a different variant
    func withVariant(_ variant: CardVariant) -> LorcanaCard {
        return LorcanaCard(
            id: "\(self.setName)_\(self.cardNumber ?? 0)_\(variant.rawValue)_\(self.name.replacingOccurrences(of: " ", with: "_"))",
            name: self.name,
            cost: self.cost,
            type: self.type,
            rarity: self.rarity,
            setName: self.setName,
            cardText: self.cardText,
            imageUrl: self.imageUrl(for: variant),
            price: self.price,
            variant: variant,
            cardNumber: self.cardNumber,
            uniqueId: self.uniqueId,
            inkwell: self.inkwell,
            strength: self.strength,
            willpower: self.willpower,
            lore: self.lore,
            franchise: self.franchise,
            inkColor: self.inkColor
        )
    }
}
