//
//  AffiliateService.swift
//  Inkwell Keeper
//
//  Manages affiliate links for TCGPlayer and eBay Partner Network
//

import Foundation

class AffiliateService {
    static let shared = AffiliateService()

    private init() {}

    // MARK: - Configuration
    // TODO: Replace with your actual affiliate IDs after approval

    private let tcgPlayerAffiliateID = "YOUR_TCGPLAYER_AFFILIATE_ID" // From Commission Junction
    private let ebayPartnerNetworkCampaignID = "YOUR_EBAY_CAMPAIGN_ID" // From eBay Partner Network

    // MARK: - TCGPlayer Affiliate Links

    /// Generate TCGPlayer affiliate link for a card
    func getTCGPlayerAffiliateLink(for card: LorcanaCard) -> URL? {
        // TCGPlayer URL format: https://www.tcgplayer.com/product/{productId}?affiliate_id={id}
        // Since we don't have product IDs, use search URL with affiliate parameter

        let searchQuery = "\(card.name) \(card.setName) Lorcana"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "https://www.tcgplayer.com/search/lorcana/product?q=\(searchQuery)&partner=\(tcgPlayerAffiliateID)"

        return URL(string: urlString)
    }

    /// Generate direct TCGPlayer product link (when you have product ID)
    func getTCGPlayerProductLink(productID: String) -> URL? {
        let urlString = "https://www.tcgplayer.com/product/\(productID)?partner=\(tcgPlayerAffiliateID)"
        return URL(string: urlString)
    }

    // MARK: - eBay Partner Network Links

    /// Generate eBay affiliate link for a card
    func getEbayAffiliateLink(for card: LorcanaCard, itemID: String? = nil) -> URL? {
        if let itemID = itemID {
            // Direct item link with affiliate tracking
            return createEbayAffiliateURL(itemID: itemID)
        } else {
            // Search results link
            return createEbaySearchURL(for: card)
        }
    }

    private func createEbayAffiliateURL(itemID: String) -> URL? {
        // eBay Partner Network link format
        let baseURL = "https://rover.ebay.com/rover/1/711-53200-19255-0/1"
        var components = URLComponents(string: baseURL)

        components?.queryItems = [
            URLQueryItem(name: "campid", value: ebayPartnerNetworkCampaignID),
            URLQueryItem(name: "customid", value: "inkwell_keeper"),
            URLQueryItem(name: "toolid", value: "10001"),
            URLQueryItem(name: "mpre", value: "https://www.ebay.com/itm/\(itemID)")
        ]

        return components?.url
    }

    private func createEbaySearchURL(for card: LorcanaCard) -> URL? {
        let searchQuery = "\(card.name) Lorcana \(card.setName) \(card.variant.displayName)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let ebaySearchURL = "https://www.ebay.com/sch/i.html?_nkw=\(searchQuery)&_sacat=183454" // 183454 = Trading Cards

        let baseURL = "https://rover.ebay.com/rover/1/711-53200-19255-0/1"
        var components = URLComponents(string: baseURL)

        components?.queryItems = [
            URLQueryItem(name: "campid", value: ebayPartnerNetworkCampaignID),
            URLQueryItem(name: "customid", value: "inkwell_keeper_search"),
            URLQueryItem(name: "toolid", value: "10001"),
            URLQueryItem(name: "mpre", value: ebaySearchURL)
        ]

        return components?.url
    }

    // MARK: - Multi-Platform Options

    struct BuyOption {
        let platform: String
        let price: Double?
        let url: URL
        let isAffiliate: Bool
    }

    /// Get all available buy options for a card
    func getBuyOptions(for card: LorcanaCard, ebayItemID: String? = nil) -> [BuyOption] {
        var options: [BuyOption] = []

        // TCGPlayer option
        if let tcgURL = getTCGPlayerAffiliateLink(for: card) {
            options.append(BuyOption(
                platform: "TCGPlayer",
                price: nil, // Can be populated if you have API access
                url: tcgURL,
                isAffiliate: true
            ))
        }

        // eBay option
        if let ebayURL = getEbayAffiliateLink(for: card, itemID: ebayItemID) {
            options.append(BuyOption(
                platform: "eBay",
                price: nil, // Can be populated from eBay API
                url: ebayURL,
                isAffiliate: true
            ))
        }

        return options
    }

    // MARK: - Revenue Tracking

    /// Track affiliate link clicks (optional analytics)
    func trackAffiliateClick(platform: String, cardName: String) {
        // TODO: Add analytics tracking here if desired
        // Could use Firebase Analytics, Mixpanel, etc.
    }

    // MARK: - Configuration Helpers

    func isConfigured() -> Bool {
        return !tcgPlayerAffiliateID.contains("YOUR_") &&
               !ebayPartnerNetworkCampaignID.contains("YOUR_")
    }

    func getTCGPlayerStatus() -> String {
        return tcgPlayerAffiliateID.contains("YOUR_") ? "Not Configured" : "Active"
    }

    func getEbayStatus() -> String {
        return ebayPartnerNetworkCampaignID.contains("YOUR_") ? "Not Configured" : "Active"
    }
}
