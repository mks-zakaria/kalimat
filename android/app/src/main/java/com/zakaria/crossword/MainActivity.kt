package com.zakaria.crossword

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import com.zakaria.crossword.data.ContentStore
import com.zakaria.crossword.data.ProgressStore
import com.zakaria.crossword.game.WordSearchContent
import com.zakaria.crossword.sound.Sounds
import com.zakaria.crossword.ui.navigation.AppNavHost
import com.zakaria.crossword.ui.navigation.Navigator
import com.zakaria.crossword.ui.theme.Fonts
import java.io.File

class MainActivity : ComponentActivity() {
    private lateinit var app: AppState

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Fonts.load(assets)

        val packs = ContentStore.loadPacks(assets)
        app = AppState(
            packs = packs,
            wsPacks = WordSearchContent.packs(packs),            // regrouped once, deterministically
            store = ProgressStore(File(filesDir, "progress.json"), BuildConfig.VERSION_NAME),
        )

        Sounds.init(this)
        Sounds.enabled = app.store.soundOn

        setContent {
            val nav = remember { Navigator() }
            val density = LocalDensity.current
            CompositionLocalProvider(
                LocalApp provides app,
                // The game is Arabic only, so the whole UI is right-to-left on every phone.
                LocalLayoutDirection provides LayoutDirection.Rtl,
                // Game boards are laid out to fit the screen, so text keeps its designed size
                // whatever the system font size is (the iOS app does the same).
                LocalDensity provides Density(density.density, fontScale = 1f),
            ) {
                AppNavHost(nav)
            }
        }
    }
}
