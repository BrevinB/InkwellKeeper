package co.brevinb.inkwellkeeper

import android.app.Application
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.disk.DiskCache
import coil3.disk.directory
import coil3.memory.MemoryCache
import coil3.request.crossfade
import co.brevinb.inkwellkeeper.billing.SubscriptionManager
import co.brevinb.inkwellkeeper.data.AppContainer
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.data.SetsDataManager

class InkwellKeeperApp : Application(), SingletonImageLoader.Factory {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        AppSettings.init(this)
        SubscriptionManager.configure(this)
        SetsDataManager.load(this)
        container = AppContainer(this)
    }

    /** Card art is remote AVIF; keep a large disk cache so browsed cards stay offline. */
    override fun newImageLoader(context: PlatformContext): ImageLoader =
        ImageLoader.Builder(context)
            .memoryCache { MemoryCache.Builder().maxSizePercent(context, 0.25).build() }
            .diskCache { DiskCache.Builder().directory(cacheDir.resolve("card_images")).maxSizeBytes(1024L * 1024 * 1024).build() }
            .crossfade(true)
            .build()

    companion object {
        lateinit var instance: InkwellKeeperApp
            private set
    }
}
