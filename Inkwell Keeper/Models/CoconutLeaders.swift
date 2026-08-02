//
//  CoconutLeaders.swift
//  Inkwell Keeper
//
//  The 18 beta leaders for Format [Coconut] — Ravensburger's multiplayer beta format
//  (open beta July 28, 2026). Leaders are digital-only cards; each unlocks up to 4 copies
//  of its associated character card in an otherwise-singleton deck.
//  Source: files.disneylorcana.com/FormatCoconut_BetaCoconutCards.pdf
//

import Foundation

struct CoconutLeader: Identifiable, Hashable {
    /// Display name of the leader card (e.g. "Ariel – \"Spectacular Singer\"").
    let name: String
    let ink: InkColor
    /// Card names the deck may run 4 copies of (the associated character card, plus
    /// extras for leaders that name additional cards — e.g. Nick Wilde's Pawpsicle).
    let fourOfCardNames: [String]
    let abilityText: String

    var id: String { name }

    /// The primary associated character card.
    var associatedCardName: String { fourOfCardNames[0] }
}

enum CoconutLeaders {
    static let all: [CoconutLeader] = [
        // Amber
        CoconutLeader(
            name: "Ariel – Spectacular Singer",
            ink: .amber,
            fourOfCardNames: ["Ariel - Spectacular Singer"],
            abilityText: "Whenever a Princess character of yours sings a song, gain lore equal to her Lore."),
        CoconutLeader(
            name: "Pocahontas – Peacekeeper",
            ink: .amber,
            fourOfCardNames: ["Pocahontas - Peacekeeper"],
            abilityText: "Once during your turn, you may choose a character. Until the start of your next turn, they get +1 Lore and can't challenge and must quest if able."),
        CoconutLeader(
            name: "Stitch – Rock Star",
            ink: .amber,
            fourOfCardNames: ["Stitch - Rock Star"],
            abilityText: "Once during your turn, you may play a character with cost 2 or less from your hand for free. If you have a character named Stitch in play, you may play a character with cost 2 or less from your discard for free instead."),
        // Amethyst
        CoconutLeader(
            name: "Dumbo – Ninth Wonder of the Universe",
            ink: .amethyst,
            fourOfCardNames: ["Dumbo - Ninth Wonder of the Universe"],
            abilityText: "You may use the exert abilities of your characters the turn they're played."),
        CoconutLeader(
            name: "Snow White – Merry as the Morning",
            ink: .amethyst,
            fourOfCardNames: ["Snow White - Merry as the Morning"],
            abilityText: "Once per game during your turn, you may reveal your hand. If you have a Snow White and 7 or more Seven Dwarfs character cards with different names among the cards in your hand, in your discard, and in play, your characters get +2 Lore for the rest of the game."),
        CoconutLeader(
            name: "Winnie the Pooh – Hunny Wizard",
            ink: .amethyst,
            fourOfCardNames: ["Winnie the Pooh - Hunny Wizard"],
            abilityText: "Whenever you play a character without an ability, you may pay 1 ink to draw a card."),
        // Emerald
        CoconutLeader(
            name: "Donald Duck – Fred Honeywell",
            ink: .emerald,
            fourOfCardNames: ["Donald Duck - Fred Honeywell"],
            abilityText: "You pay 1 ink less to use Boost abilities."),
        CoconutLeader(
            name: "Robin Hood – Sneaky Sleuth",
            ink: .emerald,
            fourOfCardNames: ["Robin Hood - Sneaky Sleuth"],
            abilityText: "Once per game during your turn, you may deal 1 damage to each opposing character."),
        CoconutLeader(
            name: "Ursula – Deceiver of All",
            ink: .emerald,
            fourOfCardNames: ["Ursula - Deceiver of All"],
            abilityText: "Your characters count as having +1 cost for singing songs. Your characters named Ursula count as having +2 cost instead."),
        // Ruby
        CoconutLeader(
            name: "Mickey Mouse – Brave Little Tailor",
            ink: .ruby,
            fourOfCardNames: ["Mickey Mouse - Brave Little Tailor"],
            abilityText: "Mickey Mouse character cards in your hand, deck, and discard gain Shift 2."),
        CoconutLeader(
            name: "Mr. Incredible – Super Strong",
            ink: .ruby,
            fourOfCardNames: ["Mr. Incredible - Super Strong"],
            abilityText: "Whenever you play a Super character, they gain Rush this turn and you may exert chosen opposing character with less Strength than them."),
        CoconutLeader(
            name: "Sisu – Emboldened Warrior",
            ink: .ruby,
            fourOfCardNames: ["Sisu - Emboldened Warrior"],
            abilityText: "All characters with more Strength than each opposing character can quest the turn they're played."),
        // Sapphire
        CoconutLeader(
            name: "Moana – Curious Explorer",
            ink: .sapphire,
            fourOfCardNames: ["Moana - Curious Explorer"],
            abilityText: "During your turn, if you have a Moana, Heihei, or Pua character in play, you may ink an additional card."),
        CoconutLeader(
            name: "Mufasa – Ruler of Pride Rock",
            ink: .sapphire,
            fourOfCardNames: ["Mufasa - Ruler of Pride Rock"],
            abilityText: "Once per game during your turn, you may pay 5 ink to put the top 3 cards of your deck into your inkwell facedown and exerted."),
        CoconutLeader(
            name: "Nick Wilde – Wily Fox",
            ink: .sapphire,
            fourOfCardNames: ["Nick Wilde - Wily Fox", "Pawpsicle"],
            abilityText: "You can have up to 4 copies of an item card named Pawpsicle in your deck. Once during your turn, you may banish 4 of your items. If you do, gain 4 lore."),
        // Steel
        CoconutLeader(
            name: "John Silver – Greedy Treasure Seeker",
            ink: .steel,
            fourOfCardNames: ["John Silver - Greedy Treasure Seeker"],
            abilityText: "Each of your locations gains Resist +1 for each character there."),
        CoconutLeader(
            name: "Scar – Finally King",
            ink: .steel,
            fourOfCardNames: ["Scar - Finally King"],
            abilityText: "During your turn, you pay 1 ink less for the first Ally character you play."),
        CoconutLeader(
            name: "Tinker Bell – Giant Fairy",
            ink: .steel,
            fourOfCardNames: ["Tinker Bell - Giant Fairy"],
            abilityText: "Whenever one of your other abilities or actions deals damage to an opposing character, deal 1 damage to that character.")
    ]

    static func leader(named name: String) -> CoconutLeader? {
        all.first { $0.name == name }
    }

    static func leaders(for ink: InkColor) -> [CoconutLeader] {
        all.filter { $0.ink == ink }
    }
}
