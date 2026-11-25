package com.zakaria.crossword.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotateRad
import androidx.compose.ui.graphics.drawscope.translate
import com.zakaria.crossword.game.SeededRng

private val confettiColors = listOf(Color(0xFFF2C55C), Color(0xFF9E3440), Color(0xFF187770), Color.White, Color(0xFFF08A4B))
private const val DURATION = 3f

/** A 3-second confetti burst from the middle of the screen. */
@Composable
fun Confetti(modifier: Modifier = Modifier) {
    var t by remember { mutableFloatStateOf(0f) }               // seconds since start
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (t < DURATION) {
            withFrameNanos { now -> t = (now - start) / 1e9f }
        }
    }
    Canvas(modifier.fillMaxSize()) {
        if (t >= DURATION) return@Canvas
        val d = density
        val rng = SeededRng("confetti")                          // same burst every time
        for (i in 0 until 90) {
            val vx = ((rng.next() % 1000uL).toFloat() / 1000f - 0.5f) * 420f * d
            val vy = (-(rng.next() % 1000uL).toFloat() / 1000f * 650f - 250f) * d
            val x = size.width / 2 + vx * t
            val y = size.height * 0.42f + vy * t + 520f * d * t * t
            translate(x, y) {
                rotateRad(t * (4 + i % 5), pivot = Offset.Zero) {
                    drawRect(
                        confettiColors[i % confettiColors.size].copy(alpha = (1 - t / DURATION).coerceAtLeast(0f)),
                        topLeft = Offset(-4 * d, -2.5f * d), size = Size(8 * d, 5 * d),
                    )
                }
            }
        }
    }
}
