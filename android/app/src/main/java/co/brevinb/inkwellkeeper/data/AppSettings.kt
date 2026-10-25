package co.brevinb.inkwellkeeper.data

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import co.brevinb.inkwellkeeper.BuildConfig
import co.brevinb.inkwellkeeper.billing.SubscriptionManager

/**
 * App preferences (the iOS app's UserDefaults/@AppStorage keys), backed by SharedPreferences
 * and exposed as Compose state so screens update when a setting changes.
 */
object AppSettings {
    private lateinit var prefs: SharedPreferences

    fun init(context: Context) {
        prefs = context.getSharedPreferences("inkwell_settings", Context.MODE_PRIVATE)
        preferredCurrency = prefs.getString("preferredCurrency", "USD") ?: "USD"
        hasCompletedOnboarding = prefs.getBoolean("hasCompletedOnboarding", false)
        hasSeenDeckIdeasNotice = prefs.getBoolean("hasSeenDeckIdeasNotice", false)
        shareIncludePrices = prefs.getBoolean("shareIncludePrices", true)
        storageShelfCollapsed = prefs.getBoolean("storageShelfCollapsed", false)
        scanDestinationContainerId = prefs.getString("scanDestinationContainerID", "") ?: ""
        lastSeenVersion = prefs.getString("lastSeenVersion", "") ?: ""
        showAllSpoilers = prefs.getBoolean("spoilers.showAll", false)
        revealedSetNames = prefs.getStringSet("spoilers.revealedSetNames", emptySet()).orEmpty()
        debugProOverride = prefs.getBoolean("debug.proUnlocked", false)
    }

    var preferredCurrency: String by mutableStateOf("USD")
        private set
    fun updatePreferredCurrency(value: String) {
        preferredCurrency = value
        prefs.edit { putString("preferredCurrency", value) }
    }

    var hasCompletedOnboarding: Boolean by mutableStateOf(false)
        private set
    fun markOnboardingComplete() {
        hasCompletedOnboarding = true
        prefs.edit { putBoolean("hasCompletedOnboarding", true) }
    }

    /** Shows onboarding again on next launch. */
    fun resetOnboarding() {
        prefs.edit { putBoolean("hasCompletedOnboarding", false) }
    }

    var hasSeenDeckIdeasNotice: Boolean by mutableStateOf(false)
        private set
    fun markDeckIdeasNoticeSeen() {
        hasSeenDeckIdeasNotice = true
        prefs.edit { putBoolean("hasSeenDeckIdeasNotice", true) }
    }

    var shareIncludePrices: Boolean by mutableStateOf(true)
        private set
    fun updateShareIncludePrices(value: Boolean) {
        shareIncludePrices = value
        prefs.edit { putBoolean("shareIncludePrices", value) }
    }

    var storageShelfCollapsed: Boolean by mutableStateOf(false)
        private set
    fun updateStorageShelfCollapsed(value: Boolean) {
        storageShelfCollapsed = value
        prefs.edit { putBoolean("storageShelfCollapsed", value) }
    }

    var scanDestinationContainerId: String by mutableStateOf("")
        private set
    fun updateScanDestination(value: String) {
        scanDestinationContainerId = value
        prefs.edit { putString("scanDestinationContainerID", value) }
    }

    var lastSeenVersion: String by mutableStateOf("")
        private set
    fun updateLastSeenVersion(value: String) {
        lastSeenVersion = value
        prefs.edit { putString("lastSeenVersion", value) }
    }

    /** True until What's New has been opened on this version, as iOS's WhatsNewManager. */
    val shouldShowWhatsNew: Boolean get() = lastSeenVersion != BuildConfig.VERSION_NAME
    fun markWhatsNewSeen() = updateLastSeenVersion(BuildConfig.VERSION_NAME)

    var showAllSpoilers: Boolean by mutableStateOf(false)
        private set
    fun updateShowAllSpoilers(value: Boolean) {
        showAllSpoilers = value
        prefs.edit { putBoolean("spoilers.showAll", value) }
    }

    var revealedSetNames: Set<String> by mutableStateOf(emptySet())
        private set
    fun revealSet(name: String) {
        revealedSetNames = revealedSetNames + name
        prefs.edit { putStringSet("spoilers.revealedSetNames", revealedSetNames) }
    }

    /** Pro entitlement: an active RevenueCat subscription, or the debug-build override (iOS's #if DEBUG premium override). */
    val isProUnlocked: Boolean get() = SubscriptionManager.isSubscribed || (BuildConfig.DEBUG && debugProOverride)

    private var debugProOverride: Boolean by mutableStateOf(false)
    fun updateProUnlocked(value: Boolean) {
        debugProOverride = value
        prefs.edit { putBoolean("debug.proUnlocked", value) }
    }

    fun getInt(key: String, default: Int): Int = prefs.getInt(key, default)
    fun putInt(key: String, value: Int) = prefs.edit { putInt(key, value) }
    fun getString(key: String): String? = prefs.getString(key, null)
    fun putString(key: String, value: String?) = prefs.edit { putString(key, value) }
}
