package com.zakaria.crossword.ui.iq

import android.os.SystemClock
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState
import com.zakaria.crossword.LocalApp

/**
 * Counts the active solving time of a level for the IQ score. The clock runs only while
 * the level is on screen, unfinished, the app is in front and [paused] is false
 * (a full-screen ad); every stretch of active time is added to the level's saved time.
 */
@Composable
fun SolveTiming(levelId: String, running: Boolean, paused: Boolean = false) {
    val store = LocalApp.current.store
    val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
    val active = running && !paused && lifecycle.isAtLeast(Lifecycle.State.RESUMED)

    // Starts when `active` turns true; when it turns false or the screen closes, the time is saved.
    DisposableEffect(active) {
        val startedAt = SystemClock.elapsedRealtime()
        onDispose {
            if (active) store.addTime(levelId, (SystemClock.elapsedRealtime() - startedAt) / 1000.0)
        }
    }
}
