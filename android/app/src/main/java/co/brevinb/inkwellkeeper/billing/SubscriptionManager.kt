package co.brevinb.inkwellkeeper.billing

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.BuildConfig
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.Offering
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore

/**
 * RevenueCat subscription state for Pro — the iOS app's SubscriptionManager, against the same
 * RevenueCat project, entitlement and offering, so one dashboard covers both stores.
 */
object SubscriptionManager {
    const val ENTITLEMENT_ID = "Ink Well Keeper Pro"
    const val OFFERING_ID = "default"
    private const val TAG = "SubscriptionManager"

    /** False until a RevenueCat key is configured; the app then runs with Pro locked. */
    val isConfigured: Boolean get() = BuildConfig.REVENUECAT_API_KEY.isNotBlank()

    var isSubscribed: Boolean by mutableStateOf(false)
        private set
    var currentOffering: Offering? by mutableStateOf(null)
        private set
    var isLoading: Boolean by mutableStateOf(false)
        private set
    var error: String? by mutableStateOf(null)

    /** RevenueCat's id for this install, which the AI proxy checks the entitlement against. */
    val appUserId: String? get() = if (isConfigured && Purchases.isConfigured) Purchases.sharedInstance.appUserID else null

    fun configure(context: Context) {
        if (!isConfigured) return
        if (BuildConfig.DEBUG) Purchases.logLevel = com.revenuecat.purchases.LogLevel.DEBUG
        Purchases.configure(PurchasesConfiguration.Builder(context.applicationContext, BuildConfig.REVENUECAT_API_KEY).build())
        // Fires for every customer-info change, including purchases made outside the app
        // (a promo code redeemed in the Play Store) and the refresh on foreground.
        Purchases.sharedInstance.updatedCustomerInfoListener = com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener { apply(it) }
    }

    suspend fun checkSubscriptionStatus() {
        if (!isConfigured) return
        runCatching { Purchases.sharedInstance.awaitCustomerInfo() }
            .onSuccess(::apply)
            .onFailure { Log.w(TAG, "Error checking status", it) }
    }

    suspend fun loadOfferings() {
        if (!isConfigured) return
        isLoading = true
        try {
            val offerings = Purchases.sharedInstance.awaitOfferings()
            currentOffering = offerings[OFFERING_ID] ?: offerings.current
        } catch (e: Exception) {
            Log.w(TAG, "Error fetching offerings", e)
            error = "Unable to load subscription options. Please try again."
        } finally {
            isLoading = false
        }
    }

    /** True when Pro is now active; false when the buyer cancelled. Throws on a failed purchase. */
    suspend fun purchase(activity: Activity, pkg: Package): Boolean {
        error = null
        isLoading = true
        try {
            val result = Purchases.sharedInstance.awaitPurchase(PurchaseParams.Builder(activity, pkg).build())
            var active = result.customerInfo.isPro()
            if (!active) {
                // The entitlement can lag the purchase on test tracks; re-fetch once.
                Purchases.sharedInstance.invalidateCustomerInfoCache()
                active = Purchases.sharedInstance.awaitCustomerInfo().isPro()
            }
            isSubscribed = active
            return active
        } catch (e: PurchasesTransactionException) {
            if (e.userCancelled) return false
            error = e.message
            throw e
        } finally {
            isLoading = false
        }
    }

    suspend fun restorePurchases() {
        error = null
        isLoading = true
        try {
            isSubscribed = Purchases.sharedInstance.awaitRestore().isPro()
            if (!isSubscribed) error = "No active subscription found."
        } catch (e: Exception) {
            error = "Unable to restore purchases. Please try again."
            throw e
        } finally {
            isLoading = false
        }
    }

    private fun apply(info: CustomerInfo) {
        isSubscribed = info.isPro()
    }

    private fun CustomerInfo.isPro() = entitlements[ENTITLEMENT_ID]?.isActive == true
}
