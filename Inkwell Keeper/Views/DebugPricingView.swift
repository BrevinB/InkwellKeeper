//
//  DebugPricingView.swift
//  Inkwell Keeper
//
//  Debug view to test eBay API pricing
//

import SwiftUI

struct DebugPricingView: View {
    private let pricingService = PricingService.shared
    @State private var testCard: LorcanaCard?
    @State private var priceResult: String = "Tap 'Test eBay API' to start"
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("eBay API Debug Tool")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.lorcanaGold)

                        Text("This tool tests the eBay Finding API integration. Check the Xcode console for detailed logs.")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaDark.opacity(0.6))
                    )

                    // Test Card Info
                    if let card = testCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Test Card")
                                .font(.headline)
                                .foregroundColor(.lorcanaGold)

                            HStack {
                                AsyncImage(url: card.bestImageUrl()) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 80, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(card.name)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text(card.setName)
                                        .font(.caption)
                                        .foregroundColor(.gray)

                                    RarityBadge(rarity: card.rarity)
                                }

                                Spacer()
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lorcanaDark.opacity(0.6))
                        )
                    }

                    // Test Button
                    Button(action: {
                        Task {
                            await testEbayAPI()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Testing...")
                            } else {
                                Image(systemName: "play.circle.fill")
                                Text("Test eBay API")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LorcanaButtonStyle())
                    .disabled(isLoading)

                    // Results
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Results")
                            .font(.headline)
                            .foregroundColor(.lorcanaGold)

                        ScrollView {
                            Text(priceResult)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 300)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.5))
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaDark.opacity(0.6))
                    )

                    // Known Issues
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Known Issues")
                            .font(.headline)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 8) {
                            issueRow(
                                icon: "exclamationmark.triangle.fill",
                                text: "Sandbox App ID: Your eBay App ID contains '-SBX-' which is for testing only. You need a production App ID."
                            )

                            issueRow(
                                icon: "network",
                                text: "Finding API: eBay Finding API may have usage limits or require additional authentication."
                            )

                            issueRow(
                                icon: "key.fill",
                                text: "Get Production Key: Visit developer.ebay.com and create a production App ID."
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.2))
                    )
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("eBay API Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadTestCard()
        }
    }

    private func issueRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.white)
        }
    }

    private func loadTestCard() {
        // Load a test card (Mickey Mouse is popular and should have eBay data)
        let dataManager = SetsDataManager.shared
        let results = dataManager.searchCards(query: "Mickey Mouse")
        testCard = results.first
    }

    private func testEbayAPI() async {
        guard let card = testCard else {
            priceResult = "❌ No test card loaded"
            return
        }

        isLoading = true
        priceResult = "🔄 Testing eBay API...\nCheck Xcode console for detailed logs.\n\n"

        do {
            let pricing = try await pricingService.getPricing(for: card, condition: .nearMint)

            if let pricing = pricing {
                var result = "✅ SUCCESS!\n\n"
                result += "Source: \(pricing.source.description)\n"
                result += "Prices found: \(pricing.prices.count)\n"
                result += "Last updated: \(pricing.lastUpdated)\n\n"

                if !pricing.prices.isEmpty {
                    result += "Price Data:\n"
                    for (index, price) in pricing.prices.prefix(5).enumerated() {
                        result += "\(index + 1). $\(String(format: "%.2f", price.price)) - \(price.marketplace)\n"
                    }

                    let avgPrice = pricing.prices.map { $0.price }.reduce(0, +) / Double(pricing.prices.count)
                    result += "\nAverage: $\(String(format: "%.2f", avgPrice))"
                } else {
                    result += "⚠️ No price data in response"
                }

                priceResult = result
            } else {
                priceResult = "⚠️ Pricing returned nil"
            }
        } catch {
            priceResult = "❌ ERROR\n\n\(error.localizedDescription)\n\nCheck console for details."
        }

        isLoading = false
    }
}

#Preview {
    DebugPricingView()
}
