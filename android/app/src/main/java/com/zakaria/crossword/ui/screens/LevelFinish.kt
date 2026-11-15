package com.zakaria.crossword.ui.screens

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.zakaria.crossword.LocalApp
import com.zakaria.crossword.data.ProgressStore
import com.zakaria.crossword.game.IQResult
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * What both game screens do when a level is finished: pay the coins (first time only),
 * score the IQ, show the level-complete card, then play the fanfare and one sound per star.
 */
class LevelFinish(
    private val store: ProgressStore,
    private val scope: CoroutineScope,
    private val levelId: String,
) {
    /** Replays earn no coins. Read when the screen opens, before this play saves anything. */
    private val alreadyDone = store.isComplete(levelId)

    var showComplete by mutableStateOf(false)
    var reward by mutableIntStateOf(0); private set
    var iq by mutableStateOf<IQResult?>(null); private set

    /** [expectedSeconds] and [hints] score the IQ (see game/IQ.kt). */
    fun finish(stars: Int, hints: Int, expectedSeconds: Double) {
        reward = if (alreadyDone) 0 else if (stars == 3) 10 else 5
        scope.launch {
            delay(500)                                  // let the last word land, and the solve clock stop
            if (reward > 0) store.earn(reward)
            iq = store.recordIQ(levelId, expectedSeconds, hints)
            showComplete = true
            delay(300)
            Sounds.play(Sound.Complete)
            repeat(stars) {
                delay(380)
                Sounds.play(Sound.Star)
            }
        }
    }
}

@Composable
fun rememberLevelFinish(levelId: String): LevelFinish {
    val store = LocalApp.current.store
    val scope = rememberCoroutineScope()
    return remember { LevelFinish(store, scope, levelId) }
}
