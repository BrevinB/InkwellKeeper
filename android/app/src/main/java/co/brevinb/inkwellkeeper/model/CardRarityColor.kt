package co.brevinb.inkwellkeeper.model

import androidx.compose.ui.graphics.Color
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

val CardRarity.color: Color
    get() = when (this) {
        CardRarity.COMMON -> SystemColors.gray
        CardRarity.UNCOMMON -> SystemColors.green
        CardRarity.RARE -> SystemColors.blue
        CardRarity.SUPER_RARE -> SystemColors.purple
        CardRarity.LEGENDARY -> SystemColors.orange
        CardRarity.ENCHANTED -> LorcanaGold
        CardRarity.EPIC -> SystemColors.indigo
        CardRarity.ICONIC -> LorcanaGold
        CardRarity.PROMO -> SystemColors.pink
    }
