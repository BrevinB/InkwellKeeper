package co.brevinb.inkwellkeeper.ui

import androidx.compose.runtime.staticCompositionLocalOf
import co.brevinb.inkwellkeeper.data.AppContainer

/** The app's managers, provided at the root like SwiftUI's environment objects. */
val LocalApp = staticCompositionLocalOf<AppContainer> { error("AppContainer not provided") }
