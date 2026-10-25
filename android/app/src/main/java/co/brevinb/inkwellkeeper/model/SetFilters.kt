package co.brevinb.inkwellkeeper.model

enum class SetOwnershipFilter(val displayName: String) { ALL("All Cards"), OWNED("Owned"), MISSING("Missing") }

/** Market-price buckets; cards without a known price only match "Any Price". */
enum class PriceFilter(val displayName: String) {
    ALL("Any Price"),
    UNDER_ONE("Under $1"),
    ONE_TO_FIVE("$1–5"),
    FIVE_TO_TWENTY("$5–20"),
    TWENTY_PLUS("$20+");

    fun matches(price: Double?): Boolean = when (this) {
        ALL -> true
        UNDER_ONE -> price != null && price < 1
        ONE_TO_FIVE -> price != null && price >= 1 && price < 5
        FIVE_TO_TWENTY -> price != null && price >= 5 && price < 20
        TWENTY_PLUS -> price != null && price >= 20
    }
}

enum class SetSortOption(val displayName: String) {
    CARD_NUMBER("Card Number"),
    PRICE_HIGH_TO_LOW("Price: High to Low"),
    PRICE_LOW_TO_HIGH("Price: Low to High"),
    RARITY("Rarity"),
}

/** Pure filtering/sorting over a set's cards. `prices` is keyed by card id. */
object SetCardFilterEngine {
    fun apply(
        cards: List<LorcanaCard>,
        ownership: SetOwnershipFilter,
        ink: InkColorFilter,
        rarity: CardRarity?,
        variant: VariantFilter,
        price: PriceFilter,
        search: String,
        prices: Map<String, Double>,
        isOwned: (LorcanaCard) -> Boolean,
    ): List<LorcanaCard> {
        var result = cards
        result = when (ownership) {
            SetOwnershipFilter.ALL -> result
            SetOwnershipFilter.OWNED -> result.filter(isOwned)
            SetOwnershipFilter.MISSING -> result.filter { !isOwned(it) }
        }
        if (ink != InkColorFilter.ALL) {
            result = result.filter { card -> card.inkColor?.split('-', ',')?.map { it.trim() }?.contains(ink.rawValue) == true }
        }
        rarity?.let { r -> result = result.filter { it.rarity == r } }
        if (variant != VariantFilter.ALL) result = result.filter { variant.matches(it.variant) }
        if (price != PriceFilter.ALL) result = result.filter { price.matches(prices[it.id]) }
        if (search.isNotEmpty()) {
            result = result.filter { card ->
                card.name.contains(search, true) || card.cardText.contains(search, true) || card.cardNumber?.toString()?.contains(search) == true
            }
        }
        return result
    }

    fun sort(cards: List<LorcanaCard>, option: SetSortOption, prices: Map<String, Double>): List<LorcanaCard> = when (option) {
        SetSortOption.CARD_NUMBER -> cards.sortedBy { it.cardNumber ?: Int.MAX_VALUE }
        SetSortOption.PRICE_HIGH_TO_LOW -> cards.sortedByDescending { prices[it.id] ?: -1.0 }
        SetSortOption.PRICE_LOW_TO_HIGH -> cards.sortedBy { prices[it.id] ?: Double.MAX_VALUE }
        SetSortOption.RARITY -> cards.sortedWith(compareByDescending<LorcanaCard> { it.rarity.sortOrder }.thenBy { it.cardNumber ?: Int.MAX_VALUE })
    }
}
