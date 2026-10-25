package co.brevinb.inkwellkeeper.ui.more

/** Free, offline reference for Lorcana keywords and core concepts (same text as iOS). */
data class GlossaryEntry(val title: String, val definition: String)

object LorcanaGlossary {
    val keywords = listOf(
        GlossaryEntry("Alert", "This character can challenge Evasive characters as if it had Evasive. Alert doesn't grant Evasive — it doesn't protect this character from being challenged."),
        GlossaryEntry("Bodyguard", "This character may enter play exerted. While a Bodyguard character is exerted, opposing characters must challenge a Bodyguard character if they challenge at all."),
        GlossaryEntry("Boost N", "Once during your turn, you may pay N ink to put the top card of your deck facedown under this card. Nobody may look at facedown cards underneath, and they're not in play — the card's other abilities say what the stack is for."),
        GlossaryEntry("Challenger +N", "This character gets +N Strength while challenging. The bonus applies only when it challenges — not when it's being challenged."),
        GlossaryEntry("Evasive", "Only characters with Evasive can challenge this character."),
        GlossaryEntry("Reckless", "This character can't quest, and must challenge each turn if able."),
        GlossaryEntry("Resist +N", "Damage dealt to this character is reduced by N."),
        GlossaryEntry("Rush", "This character can challenge the turn it's played. Rush doesn't allow questing that turn — its ink is still drying for everything else."),
        GlossaryEntry("Shift N", "You may pay N ink to play this character on top of one of your characters with the specified name. The shifted character keeps damage, its ready/exerted state, and can act as if it were the character beneath. Newer sets add variants — classification Shift, Universal, Duo, Combo, Temporary, and Potato Shift — that change what you may shift onto; the card spells out which."),
        GlossaryEntry("Singer N", "This character counts as costing N for the purpose of singing songs, letting them sing songs of cost N or less."),
        GlossaryEntry("Sing Together N", "You may exert any number of your characters with total cost N or more to sing this song for free."),
        GlossaryEntry("Support", "Whenever this character quests, you may add its Strength to another chosen character's Strength this turn."),
        GlossaryEntry("Ward", "Opponents can't choose this character with effects. Challenges don't \"choose,\" so Ward characters can still be challenged."),
        GlossaryEntry("Vanish", "When an opponent chooses this character for an action, this character is banished."),
    )

    val concepts = listOf(
        GlossaryEntry("Inkwell & Inkable", "Once per turn you may put a card with the inkwell symbol facedown into your inkwell. Cards there are ink — exert them to pay costs. They stay facedown for the rest of the game."),
        GlossaryEntry("Drying", "The turn a character is played, its ink is drying: it can't quest, challenge, or exert to use abilities until your next turn (unless something like Rush says otherwise)."),
        GlossaryEntry("Quest", "Exert a dry character to gain lore equal to its Lore value. First player to 20 lore wins."),
        GlossaryEntry("Challenge", "Exert a dry character to challenge an exerted opposing character (or a location). The two characters deal damage to each other equal to their Strength."),
        GlossaryEntry("Banish", "A banished card goes to its player's discard pile. Characters are banished when damage on them meets or exceeds their Willpower."),
        GlossaryEntry("Locations", "Locations enter play like characters and can gain you lore at the start of your turn. Characters may move to a location by paying its move cost, and locations can be challenged directly."),
    )
}
