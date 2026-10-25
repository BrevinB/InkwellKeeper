package co.brevinb.inkwellkeeper.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold

@Composable
fun PlaceholderScreen(title: String, showBack: Boolean = true) {
    InkwellScaffold(title = title, showBack = showBack) { padding ->
        EmptyState(Icons.Filled.Construction, title, "Coming soon on Android.", Modifier.padding(padding))
    }
}
