package com.zakaria.crossword

import androidx.compose.runtime.staticCompositionLocalOf
import com.zakaria.crossword.data.ProgressStore
import com.zakaria.crossword.model.Pack

/** What every screen needs, created once in MainActivity and handed down through [LocalApp]. */
class AppState(
    val packs: List<Pack>,          // crossword packs
    val wsPacks: List<Pack>,        // word-search packs, regrouped from the same clues
    val store: ProgressStore,
)

val LocalApp = staticCompositionLocalOf<AppState> { error("AppState not provided") }
