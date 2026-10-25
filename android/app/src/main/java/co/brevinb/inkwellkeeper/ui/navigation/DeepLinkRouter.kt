package co.brevinb.inkwellkeeper.ui.navigation

import android.net.Uri

/** A destination requested by an external link (custom scheme or https App Link). */
sealed interface DeepLinkRoute {
    data class Deck(val code: String) : DeepLinkRoute
    data class Card(val id: String) : DeepLinkRoute
    data class Set(val name: String) : DeepLinkRoute
}

object DeepLinkRouter {
    const val SCHEME = "inkwellkeeper"
    const val UNIVERSAL_HOST = "inkwellkeeper.app"
    const val PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=co.brevinb.inkwellkeeper"
    const val APP_STORE_URL = "https://apps.apple.com/us/app/ink-well-keeper/id6754206379"

    /** QR codes lose scannability past roughly this payload size. */
    const val MAX_DECK_CODE_LENGTH_FOR_QR = 900

    /** Parses `inkwellkeeper://deck?code=…` or `https://inkwellkeeper.app/deck?code=…`. */
    fun parse(uri: Uri): DeepLinkRoute? {
        val verb = when {
            uri.scheme == SCHEME -> uri.host.orEmpty()
            uri.scheme == "https" && uri.host == UNIVERSAL_HOST -> uri.pathSegments.firstOrNull().orEmpty()
            else -> return null
        }
        // getQueryParameter turns '+' into a space; legacy codes use standard base64.
        fun query(name: String): String? = uri.encodedQuery?.split("&")
            ?.map { it.split("=", limit = 2) }
            ?.firstOrNull { it.size == 2 && it[0] == name }
            ?.let { Uri.decode(it[1]) }
            ?.takeIf { it.isNotEmpty() }
        return when (verb) {
            "deck" -> query("code")?.let { DeepLinkRoute.Deck(it) }
            "card" -> query("id")?.let { DeepLinkRoute.Card(it) }
            "set" -> query("name")?.let { DeepLinkRoute.Set(it) }
            else -> null
        }
    }

    fun deckShareLink(code: String) = "https://$UNIVERSAL_HOST/deck?code=${Uri.encode(code)}"
    fun deckQrPayload(code: String) = if (code.length <= MAX_DECK_CODE_LENGTH_FOR_QR) deckShareLink(code) else APP_STORE_URL
    fun cardQrPayload(id: String) = "https://$UNIVERSAL_HOST/card?id=${Uri.encode(id)}"
    fun setQrPayload(name: String) = "https://$UNIVERSAL_HOST/set?name=${Uri.encode(name)}"
}
