//
//  LorcanaCardExtensions.swift
//  Inkwell Keeper
//
//  Extensions for LorcanaCard to support variant-specific images
//

import Foundation

extension LorcanaCard {
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
