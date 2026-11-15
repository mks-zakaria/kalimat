package com.zakaria.crossword

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import com.zakaria.crossword.ui.components.SceneBackground
import com.zakaria.crossword.ui.components.SceneMood
import com.zakaria.crossword.ui.theme.Fonts

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Fonts.load(assets)
        setContent {
            // The game is Arabic only, so the whole UI is right-to-left on every phone.
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                SceneBackground(SceneMood.Sunset, duneHeight = 0.34f)
            }
        }
    }
}
