package com.zakaria.crossword.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import kotlin.math.PI
import kotlin.math.sin

/** Horizontal shake for a wrong answer: call [start] and add [modifier] to what should shake. */
class Shake(private val progress: Animatable<Float, *>) {
    suspend fun start() {
        progress.snapTo(0f)
        progress.animateTo(1f, tween(350))
    }

    val modifier: Modifier
        get() = Modifier.graphicsLayer { translationX = 8 * density * sin(progress.value * PI.toFloat() * 4) }
}

@Composable
fun rememberShake(): Shake = remember { Shake(Animatable(1f)) }
