package co.brevinb.inkwellkeeper.model

/**
 * A Format [Coconut] beta leader. Each unlocks up to 4 copies of its associated card(s) in an
 * otherwise-singleton deck. Source: files.disneylorcana.com/FormatCoconut_BetaCoconutCards.pdf
 */
data class CoconutLeader(
    val name: String,
    val ink: InkColor,
    val fourOfCardNames: List<String>,
    val abilityText: String,
) {
    val associatedCardName: String get() = fourOfCardNames.first()
}

object CoconutLeaders {
    val all: List<CoconutLeader> = listOf(
        CoconutLeader("Ariel – Spectacular Singer", InkColor.AMBER, listOf("Ariel - Spectacular Singer"), "Whenever a Princess character of yours sings a song, gain lore equal to her Lore."),
        CoconutLeader("Pocahontas – Peacekeeper", InkColor.AMBER, listOf("Pocahontas - Peacekeeper"), "Once during your turn, you may choose a character. Until the start of your next turn, they get +1 Lore and can't challenge and must quest if able."),
        CoconutLeader("Stitch – Rock Star", InkColor.AMBER, listOf("Stitch - Rock Star"), "Once during your turn, you may play a character with cost 2 or less from your hand for free. If you have a character named Stitch in play, you may play a character with cost 2 or less from your discard for free instead."),
        CoconutLeader("Dumbo – Ninth Wonder of the Universe", InkColor.AMETHYST, listOf("Dumbo - Ninth Wonder of the Universe"), "You may use the exert abilities of your characters the turn they're played."),
        CoconutLeader("Snow White – Merry as the Morning", InkColor.AMETHYST, listOf("Snow White - Merry as the Morning"), "Once per game during your turn, you may reveal your hand. If you have a Snow White and 7 or more Seven Dwarfs character cards with different names among the cards in your hand, in your discard, and in play, your characters get +2 Lore for the rest of the game."),
        CoconutLeader("Winnie the Pooh – Hunny Wizard", InkColor.AMETHYST, listOf("Winnie the Pooh - Hunny Wizard"), "Whenever you play a character without an ability, you may pay 1 ink to draw a card."),
        CoconutLeader("Donald Duck – Fred Honeywell", InkColor.EMERALD, listOf("Donald Duck - Fred Honeywell"), "You pay 1 ink less to use Boost abilities."),
        CoconutLeader("Robin Hood – Sneaky Sleuth", InkColor.EMERALD, listOf("Robin Hood - Sneaky Sleuth"), "Once per game during your turn, you may deal 1 damage to each opposing character."),
        CoconutLeader("Ursula – Deceiver of All", InkColor.EMERALD, listOf("Ursula - Deceiver of All"), "Your characters count as having +1 cost for singing songs. Your characters named Ursula count as having +2 cost instead."),
        CoconutLeader("Mickey Mouse – Brave Little Tailor", InkColor.RUBY, listOf("Mickey Mouse - Brave Little Tailor"), "Mickey Mouse character cards in your hand, deck, and discard gain Shift 2."),
        CoconutLeader("Mr. Incredible – Super Strong", InkColor.RUBY, listOf("Mr. Incredible - Super Strong"), "Whenever you play a Super character, they gain Rush this turn and you may exert chosen opposing character with less Strength than them."),
        CoconutLeader("Sisu – Emboldened Warrior", InkColor.RUBY, listOf("Sisu - Emboldened Warrior"), "All characters with more Strength than each opposing character can quest the turn they're played."),
        CoconutLeader("Moana – Curious Explorer", InkColor.SAPPHIRE, listOf("Moana - Curious Explorer"), "During your turn, if you have a Moana, Heihei, or Pua character in play, you may ink an additional card."),
        CoconutLeader("Mufasa – Ruler of Pride Rock", InkColor.SAPPHIRE, listOf("Mufasa - Ruler of Pride Rock"), "Once per game during your turn, you may pay 5 ink to put the top 3 cards of your deck into your inkwell facedown and exerted."),
        CoconutLeader("Nick Wilde – Wily Fox", InkColor.SAPPHIRE, listOf("Nick Wilde - Wily Fox", "Pawpsicle"), "You can have up to 4 copies of an item card named Pawpsicle in your deck. Once during your turn, you may banish 4 of your items. If you do, gain 4 lore."),
        CoconutLeader("John Silver – Greedy Treasure Seeker", InkColor.STEEL, listOf("John Silver - Greedy Treasure Seeker"), "Each of your locations gains Resist +1 for each character there."),
        CoconutLeader("Scar – Finally King", InkColor.STEEL, listOf("Scar - Finally King"), "During your turn, you pay 1 ink less for the first Ally character you play."),
        CoconutLeader("Tinker Bell – Giant Fairy", InkColor.STEEL, listOf("Tinker Bell - Giant Fairy"), "Whenever one of your other abilities or actions deals damage to an opposing character, deal 1 damage to that character."),
    )

    fun leader(named: String?): CoconutLeader? = all.firstOrNull { it.name == named }

    fun leaders(ink: InkColor): List<CoconutLeader> = all.filter { it.ink == ink }
}
