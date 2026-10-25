package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.AutoFixHigh
import androidx.compose.material.icons.filled.Crop54
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Stars
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.ui.graphics.vector.ImageVector
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.model.InkColorFilter
import co.brevinb.inkwellkeeper.model.VariantFilter

/** Material stand-ins for the SF Symbols the iOS filters use. */
val InkColorFilter.icon: ImageVector
    get() = when (this) {
        InkColorFilter.ALL -> Icons.Filled.GridView
        InkColorFilter.AMBER -> Icons.Filled.WbSunny
        InkColorFilter.AMETHYST -> Icons.Filled.AutoAwesome
        InkColorFilter.EMERALD -> Icons.Filled.Eco
        InkColorFilter.RUBY -> Icons.Filled.LocalFireDepartment
        InkColorFilter.SAPPHIRE -> Icons.Filled.WaterDrop
        InkColorFilter.STEEL -> Icons.Filled.Shield
    }

val InkColor.icon: ImageVector
    get() = when (this) {
        InkColor.AMBER -> Icons.Filled.WbSunny
        InkColor.AMETHYST -> Icons.Filled.AutoAwesome
        InkColor.EMERALD -> Icons.Filled.Eco
        InkColor.RUBY -> Icons.Filled.LocalFireDepartment
        InkColor.SAPPHIRE -> Icons.Filled.WaterDrop
        InkColor.STEEL -> Icons.Filled.Shield
    }

val VariantFilter.icon: ImageVector
    get() = when (this) {
        VariantFilter.ALL -> Icons.Filled.Layers
        VariantFilter.NORMAL -> Icons.Filled.Crop54
        VariantFilter.FOIL -> Icons.Filled.AutoAwesome
        VariantFilter.ENCHANTED -> Icons.Filled.AutoFixHigh
        VariantFilter.PROMO -> Icons.Filled.Stars
        VariantFilter.SPECIAL -> Icons.Filled.WorkspacePremium
    }
