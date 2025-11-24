import Foundation

// Test script to verify promo card JSON is loading correctly

struct TestCard: Codable {
    let id: String
    let name: String
    let uniqueId: String?
    let setName: String
    let cardNumber: Int?
    let variant: String?
}

struct TestSet: Codable {
    let setName: String
    let cards: [TestCard]
}

// Test D23 Collection (smallest set)
let d23Path = "Inkwell Keeper/Data/d23_collection.json"

if let fileURL = URL(string: "file:///Users/brevin/Developer/Inkwell Keeper/\(d23Path)"),
   let data = try? Data(contentsOf: fileURL),
   let set = try? JSONDecoder().decode(TestSet.self, from: data) {

    print("✅ Successfully loaded \(set.setName)")
    print("   Found \(set.cards.count) cards")

    for card in set.cards.prefix(3) {
        print("\n📇 Card:")
        print("   Name: \(card.name)")
        print("   ID: \(card.id)")
        print("   uniqueId: \(card.uniqueId ?? "nil")")
        print("   setName: \(card.setName)")
        print("   cardNumber: \(card.cardNumber?.description ?? "nil")")
        print("   variant: \(card.variant ?? "nil")")
    }
} else {
    print("❌ Failed to load D23 Collection")
}
