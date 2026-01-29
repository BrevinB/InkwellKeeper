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
        guard let uniqueId = self.uniqueId else {
            print("⚠️ [localImageUrl] No uniqueId for card: \(name)")
            return nil
        }

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
            "Reign of Jafar": "reign_of_jafar",
            "Whispers in the Well": "whispers_in_the_well",
            "Winterspell": "winterspell",
            "Promo Set 1": "promo_set_1",
            "Promo Set 2": "promo_set_2",
            "Challenge Promo": "challenge_promo",
            "D23 Collection": "d23_collection"
        ]

        guard let folderName = setFolderMap[setName] else {
            print("⚠️ [localImageUrl] No folder mapping for set: \(setName)")
            return nil
        }

        // Construct filename with variant suffix if not normal
        // Note: Foil uses the same image as normal (we apply a visual effect instead)
        let variantSuffix: String
        switch variant {
        case .normal, .foil:
            variantSuffix = ""
        case .enchanted:
            variantSuffix = "-enchanted"
        case .promo:
            variantSuffix = "-promo"
        case .borderless:
            variantSuffix = "-borderless"
        case .epic:
            variantSuffix = "-epic"
        case .iconic:
            variantSuffix = "-iconic"
        }

        print("🔍 [localImageUrl] Looking for image:")
        print("   Card: \(name)")
        print("   uniqueId: \(uniqueId)")
        print("   Variant: \(variant.rawValue)")
        print("   Folder: \(folderName)")
        print("   Suffix: \(variantSuffix)")

        // Debug: List what's actually in the bundle
        if let bundlePath = Bundle.main.resourcePath {
            print("   Bundle path: \(bundlePath)")

            // Try to list the whispers_in_the_well folder contents
            let possiblePaths = [
                "\(bundlePath)/CardImages/\(folderName)",
                "\(bundlePath)/Resources/CardImages/\(folderName)",
                "\(bundlePath)/\(folderName)"
            ]

            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    print("   📁 Found folder at: \(path)")
                    if let contents = try? FileManager.default.contentsOfDirectory(atPath: path) {
                        let enchantedFiles = contents.filter { $0.contains("enchanted") }.prefix(3)
                        if !enchantedFiles.isEmpty {
                            print("   Sample enchanted files: \(enchantedFiles.joined(separator: ", "))")
                        }
                    }
                    break
                }
            }
        }

        // Try both .png and .jpg extensions
        let extensions = ["jpg", "png", "avif"]

        for ext in extensions {
            let filename = "\(uniqueId)\(variantSuffix).\(ext)"
            print("   Trying: \(filename)")

            // Try at bundle root (no subdirectory) - Xcode flattens folder references
            if let url = Bundle.main.url(
                forResource: filename.replacingOccurrences(of: ".\(ext)", with: ""),
                withExtension: ext
            ) {
                print("   ✅ Found: \(url.lastPathComponent) at bundle root")
                return url
            }

            // Also try subdirectory paths as fallback
            let subdirectoryPaths = [
                "CardImages/\(folderName)",
                "Resources/CardImages/\(folderName)",
                folderName
            ]

            for subdirectory in subdirectoryPaths {
                if let url = Bundle.main.url(
                    forResource: filename.replacingOccurrences(of: ".\(ext)", with: ""),
                    withExtension: ext,
                    subdirectory: subdirectory
                ) {
                    print("   ✅ Found: \(url.lastPathComponent) in \(subdirectory)")
                    return url
                }
            }
        }

        print("   ❌ No local image found in any path")
        return nil
    }

    /// Get the best available image URL - prefers local, falls back to remote
    /// Takes the card's variant into account when constructing the URL
    func bestImageUrl() -> URL? {
        // Always try local first for ALL variants (now includes enchanted, promo, etc.)
        if let localUrl = localImageUrl() {
            return localUrl
        }

        // Fall back to remote URL (with variant consideration)
        let urlString = variant == .normal ? imageUrl : constructVariantUrl(for: variant)
        return URL(string: urlString)
    }

    /// Construct a variant-specific URL based on Lorcana API patterns
    private func constructVariantUrl(for variant: CardVariant) -> String {
        // If it's the normal variant or the card already has the right variant, use existing URL
        if variant == .normal || variant == self.variant {
            return self.imageUrl
        }

        let baseUrl = self.imageUrl

        // Check if this is a Lorcana API URL
        guard baseUrl.contains("lorcana-api.com") || baseUrl.contains("lorcania.com") else {
            return baseUrl  // Not a known Lorcana API URL, return as-is
        }

        let variantSuffix: String
        switch variant {
        case .normal:
            return baseUrl
        case .foil:
            variantSuffix = "foil"
        case .borderless:
            variantSuffix = "borderless"
        case .promo:
            variantSuffix = "promo"
        case .enchanted:
            variantSuffix = "enchanted"
        case .epic:
            variantSuffix = "epic"
        case .iconic:
            variantSuffix = "iconic"
        }

        // Try different URL patterns
        // Pattern 1: {base}-{variant}.png or {base}-{variant}-large.png
        if baseUrl.hasSuffix("-large.png") {
            let withoutSuffix = baseUrl.replacingOccurrences(of: "-large.png", with: "")
            return "\(withoutSuffix)-\(variantSuffix)-large.png"
        } else if baseUrl.hasSuffix(".png") {
            let withoutSuffix = baseUrl.replacingOccurrences(of: ".png", with: "")
            return "\(withoutSuffix)-\(variantSuffix).png"
        } else if baseUrl.hasSuffix(".jpg") {
            let withoutSuffix = baseUrl.replacingOccurrences(of: ".jpg", with: "")
            return "\(withoutSuffix)-\(variantSuffix).jpg"
        }

        return baseUrl
    }

    /// Get the image URL for a specific variant
    /// Attempts to construct variant-specific URL, falls back to base image if not available
    func imageUrl(for variant: CardVariant) -> String {
        return constructVariantUrl(for: variant)
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

    /// Check if a specific variant image exists for this card
    func hasVariant(_ variant: CardVariant) -> Bool {
        // Normal variant always exists (it's the base card)
        if variant == .normal {
            return true
        }

        // Foil variant is always available (it's a visual effect, not a different image)
        if variant == .foil {
            return true
        }

        // Check if variant image exists in bundle
        guard let uniqueId = self.uniqueId else { return false }

        let variantSuffix: String
        switch variant {
        case .normal:
            return true
        case .enchanted:
            variantSuffix = "-enchanted"
        case .promo:
            variantSuffix = "-promo"
        case .foil:
            variantSuffix = "-foil"
        case .borderless:
            variantSuffix = "-borderless"
        case .epic:
            variantSuffix = "-epic"
        case .iconic:
            variantSuffix = "-iconic"
        }

        // Check for file existence in bundle
        let extensions = ["jpg", "png", "avif"]
        for ext in extensions {
            let filename = "\(uniqueId)\(variantSuffix)"
            if Bundle.main.url(forResource: filename, withExtension: ext) != nil {
                return true
            }
        }

        return false
    }

    /// Get list of available variants for this card
    /// Note: Enchanted, Epic, and Iconic are separate cards, not variants you can choose
    func availableVariants() -> [CardVariant] {
        // Enchanted, Epic, Iconic, and Promo are separate cards, not selectable variants
        if self.variant == .enchanted || self.variant == .epic ||
           self.variant == .iconic || self.variant == .promo {
            return [self.variant]
        }

        // For normal cards, only allow Normal and Foil (same card, different finish)
        return [.normal, .foil]
    }
}
