package com.zakaria.crossword.ui.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Composable
import com.zakaria.crossword.model.isWordSearch
import com.zakaria.crossword.ui.screens.BoardScreen
import com.zakaria.crossword.ui.screens.HomeScreen
import com.zakaria.crossword.ui.screens.LevelsScreen
import com.zakaria.crossword.ui.screens.PacksScreen
import com.zakaria.crossword.ui.screens.WordSearchScreen

/** Shows the screen on top of the back stack; the system back gesture pops it. */
@Composable
fun AppNavHost(nav: Navigator) {
    BackHandler(enabled = nav.canGoBack) { nav.pop() }

    AnimatedContent(
        targetState = nav.current,
        transitionSpec = { fadeIn() togetherWith fadeOut() },
        label = "screens",
    ) { route ->
        when (route) {
            Route.Home -> HomeScreen(nav)
            is Route.Packs -> PacksScreen(nav, route.mode)
            is Route.Levels -> LevelsScreen(nav, route.pack)
            is Route.Board ->
                if (route.pack.isWordSearch) WordSearchScreen(nav, route.level, route.pack)
                else BoardScreen(nav, route.level, route.pack)
        }
    }
}
