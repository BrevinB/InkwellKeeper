package co.brevinb.inkwellkeeper

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.ui.InkwellApp
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRoute
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRouter
import co.brevinb.inkwellkeeper.ui.theme.InkwellTheme

class MainActivity : ComponentActivity() {
    private var pendingDeepLink by mutableStateOf<DeepLinkRoute?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        val container = (application as InkwellKeeperApp).container
        setContent {
            InkwellTheme {
                CompositionLocalProvider(LocalApp provides container) {
                    InkwellApp(pendingDeepLink, onDeepLinkHandled = { pendingDeepLink = null })
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun onStop() {
        super.onStop()
        (application as InkwellKeeperApp).container.flush()
    }

    private fun handleIntent(intent: Intent?) {
        val uri = intent?.data ?: return
        DeepLinkRouter.parse(uri)?.let { pendingDeepLink = it }
    }
}
