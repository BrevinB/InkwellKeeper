package co.brevinb.inkwellkeeper.data

import android.util.Log

/**
 * Event hook mirroring the iOS `Analytics.send`. iOS reports to TelemetryDeck; on Android
 * events are only logged until an analytics SDK is chosen (no third-party SDKs were added).
 */
object Analytics {
    fun send(event: String, parameters: Map<String, String> = emptyMap()) {
        Log.d("IWK-Analytics", if (parameters.isEmpty()) event else "$event $parameters")
    }
}
