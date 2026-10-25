package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.style.TextOverflow
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/**
 * Screen chrome: Lorcana background, a transparent top bar (large title like iOS navigation
 * titles when [large]), and an optional back button.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InkwellScaffold(
    title: String,
    modifier: Modifier = Modifier,
    large: Boolean = false,
    showBack: Boolean = false,
    onBack: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
    titleContent: (@Composable () -> Unit)? = null,
    snackbarHostState: SnackbarHostState = remember { SnackbarHostState() },
    floatingActionButton: @Composable () -> Unit = {},
    bottomBar: @Composable () -> Unit = {},
    content: @Composable (PaddingValues) -> Unit,
) {
    val nav = LocalNav.current
    val colors = TopAppBarDefaults.topAppBarColors(
        containerColor = Color.Transparent,
        scrolledContainerColor = Color(0xE6141420),
        titleContentColor = Color.White,
        navigationIconContentColor = LorcanaGold,
        actionIconContentColor = LorcanaGold,
    )
    val scrollBehavior = if (large) TopAppBarDefaults.exitUntilCollapsedScrollBehavior() else TopAppBarDefaults.pinnedScrollBehavior()
    val navigationIcon: @Composable () -> Unit = {
        if (showBack || onBack != null) {
            IconButton(onClick = { onBack?.invoke() ?: nav.popBackStack() }) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
        }
    }
    LorcanaBackground {
        Scaffold(
            modifier = modifier.fillMaxSize().nestedScroll(scrollBehavior.nestedScrollConnection),
            containerColor = Color.Transparent,
            contentWindowInsets = WindowInsets(0),
            snackbarHost = { SnackbarHost(snackbarHostState) },
            floatingActionButton = floatingActionButton,
            bottomBar = bottomBar,
            topBar = {
                val titleSlot: @Composable () -> Unit = titleContent ?: {
                    Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                if (large) {
                    LargeTopAppBar(title = titleSlot, navigationIcon = navigationIcon, actions = actions, colors = colors, scrollBehavior = scrollBehavior)
                } else {
                    TopAppBar(
                        title = { Box { androidx.compose.runtime.CompositionLocalProvider(androidx.compose.material3.LocalTextStyle provides MaterialTheme.typography.titleMedium) { titleSlot() } } },
                        navigationIcon = navigationIcon,
                        actions = actions,
                        colors = colors,
                        scrollBehavior = scrollBehavior,
                    )
                }
            },
            content = content,
        )
    }
}
