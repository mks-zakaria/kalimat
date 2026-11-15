package com.zakaria.crossword.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import com.zakaria.crossword.LocalApp
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds
import com.zakaria.crossword.ui.coins.CoinsCard
import com.zakaria.crossword.ui.theme.Space

/** End of every top bar (left in Arabic): sound on/off and the coin counter (tap it for the coins card). */
@Composable
fun TopBarActions() {
    val store = LocalApp.current.store
    var showCoins by remember { mutableStateOf(false) }
    Row(horizontalArrangement = Arrangement.spacedBy(Space.sm), verticalAlignment = Alignment.CenterVertically) {
        // keep the speaker pointing the usual way, even in the right-to-left layout
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            RoundIconButton(
                icon = if (store.soundOn) Icons.AutoMirrored.Filled.VolumeUp else Icons.AutoMirrored.Filled.VolumeOff,
                label = if (store.soundOn) "الصوت يعمل، اضغط للكتم" else "الصوت مكتوم، اضغط للتشغيل",
                onClick = {
                    store.soundOn = !store.soundOn
                    Sounds.enabled = store.soundOn
                    Sounds.play(Sound.Tap)             // audible only when turning sound on
                },
            )
        }
        CoinBadge(store.coins, Modifier.pressable { Sounds.play(Sound.Coin); showCoins = true })
    }
    if (showCoins) CoinsCard(onClose = { showCoins = false })
}
