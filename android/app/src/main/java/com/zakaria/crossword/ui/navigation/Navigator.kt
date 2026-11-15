package com.zakaria.crossword.ui.navigation

import androidx.compose.runtime.mutableStateListOf
import com.zakaria.crossword.model.GameMode
import com.zakaria.crossword.model.Level
import com.zakaria.crossword.model.Pack
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds

/** Every screen of the app. */
sealed interface Route {
    data object Home : Route
    data class Packs(val mode: GameMode) : Route
    data class Levels(val pack: Pack) : Route
    data class Board(val level: Level, val pack: Pack) : Route
}

/** A simple back stack: the last route is the screen on show. */
class Navigator {
    val stack = mutableStateListOf<Route>(Route.Home)

    val current: Route get() = stack.last()
    val canGoBack: Boolean get() = stack.size > 1

    fun push(route: Route) {
        Sounds.play(Sound.Open)
        stack.add(route)
    }

    fun pop() {
        if (canGoBack) stack.removeAt(stack.lastIndex)
    }

    /** Leaves a finished level and opens the next one in its place. */
    fun replaceTop(route: Route) {
        stack[stack.lastIndex] = route
    }
}
