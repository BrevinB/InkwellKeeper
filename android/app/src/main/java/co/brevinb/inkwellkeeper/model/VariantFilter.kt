package co.brevinb.inkwellkeeper.model

enum class VariantFilter(val displayName: String) {
    ALL("All"),
    NORMAL("Normal"),
    FOIL("Foil"),
    ENCHANTED("Enchanted"),
    PROMO("Promo"),
    /** Epic, Iconic, Borderless. */
    SPECIAL("Special");

    fun matches(variant: CardVariant): Boolean = when (this) {
        ALL -> true
        NORMAL -> variant == CardVariant.NORMAL
        FOIL -> variant == CardVariant.FOIL
        ENCHANTED -> variant == CardVariant.ENCHANTED
        PROMO -> variant == CardVariant.PROMO
        SPECIAL -> variant == CardVariant.EPIC || variant == CardVariant.ICONIC || variant == CardVariant.BORDERLESS
    }
}
