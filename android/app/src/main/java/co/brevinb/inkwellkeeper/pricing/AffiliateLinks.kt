package co.brevinb.inkwellkeeper.pricing

import android.net.Uri
import co.brevinb.inkwellkeeper.model.LorcanaCard

/** Marketplace links for a card, matching the iOS `AffiliateService`. */
object AffiliateLinks {
    private const val TCGPLAYER_AFFILIATE_ID = "YOUR_TCGPLAYER_AFFILIATE_ID"
    private const val EBAY_CAMPAIGN_ID = "5339128910"

    data class BuyOption(val platform: String, val url: String)

    fun tcgPlayer(card: LorcanaCard): String =
        "https://www.tcgplayer.com/search/lorcana/product?q=${Uri.encode("${card.name} ${card.setName} Lorcana")}&partner=$TCGPLAYER_AFFILIATE_ID"

    fun cardmarket(card: LorcanaCard): String {
        val hyphenated = card.name.replace(" - ", "-").replace(" ", "-")
        return if (hyphenated.isEmpty()) {
            "https://www.cardmarket.com/en/Lorcana/Products/Search?searchString=${Uri.encode(card.name)}"
        } else {
            "https://www.cardmarket.com/en/Lorcana/Cards/${Uri.encode(hyphenated, "-")}"
        }
    }

    fun ebay(card: LorcanaCard): String {
        val query = Uri.encode("${card.name} Lorcana ${card.setName} ${card.variant.displayName}")
        return "https://www.ebay.com/sch/i.html?_nkw=$query&_sacat=183454&mkcid=1&mkrid=711-53200-19255-0&siteid=0" +
            "&campid=$EBAY_CAMPAIGN_ID&customid=inkwell_keeper_search&toolid=10001"
    }

    fun buyOptions(card: LorcanaCard): List<BuyOption> = listOf(
        BuyOption("TCGPlayer", tcgPlayer(card)),
        BuyOption("Cardmarket", cardmarket(card)),
        BuyOption("eBay", ebay(card)),
    )
}
