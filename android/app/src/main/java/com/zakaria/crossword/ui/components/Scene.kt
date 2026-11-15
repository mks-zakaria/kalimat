package com.zakaria.crossword.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.translate
import com.zakaria.crossword.game.SeededRng
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Colours of one desert scene. Each pack has its own mood (pack 1 dawn, 2 day, 3 sunset, 4 night, 5 dawn…). */
enum class SceneMood(val sky: List<Color>, val dunes: List<Color>, val sun: Color) {
    Dawn(
        listOf(Color(0xFF4B3A6E), Color(0xFF9C5B7F), Color(0xFFF0A27A)),
        listOf(Color(0xFFC98B73), Color(0xFFDDA27D), Color(0xFFEBBE8E)), Color(0xFFFFD3A1),
    ),
    Day(
        listOf(Color(0xFF2F6FA8), Color(0xFF5FA3D6), Color(0xFFBFE0F2)),
        listOf(Color(0xFFE2B77C), Color(0xFFEBC68D), Color(0xFFF3D7A4)), Color(0xFFFFF3C4),
    ),
    Sunset(
        listOf(Color(0xFF2A1F4D), Color(0xFF8A3B5C), Color(0xFFF08A4B)),
        listOf(Color(0xFF9B4F48), Color(0xFFC06B4E), Color(0xFFDB8C5C)), Color(0xFFFFB45E),
    ),
    Night(
        listOf(Color(0xFF0E1430), Color(0xFF1B2340), Color(0xFF34406B)),
        listOf(Color(0xFF2D2F55), Color(0xFF3B3C66), Color(0xFF4C4B76)), Color(0xFFF4EFD9),
    );

    val hasStars: Boolean get() = this == Night || this == Dawn

    companion object {
        fun forPack(order: Int): SceneMood = entries[(maxOf(order, 1) - 1) % 4]
    }
}

/**
 * Original desert artwork, drawn in code: sky, stars, a faint girih pattern, sun or moon,
 * three dune layers and a palm. The x positions are mirrored (sun on the right, palm on the
 * left) because the iOS app draws the scene in a right-to-left layout.
 *
 * [duneHeight] is the share of the height the dunes take (0..1).
 */
@Composable
fun SceneBackground(mood: SceneMood, modifier: Modifier = Modifier, duneHeight: Float = 0.32f, animated: Boolean = true) {
    val drift = if (animated) {
        rememberInfiniteTransition(label = "scene")
            .animateFloat(-1f, 1f, infiniteRepeatable(tween(6000), RepeatMode.Reverse), label = "drift").value
    } else 0f

    Canvas(modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        drawRect(Brush.verticalGradient(mood.sky))
        if (mood.hasStars) drawStars(if (mood == SceneMood.Night) 0.9f else 0.4f)
        drawGirih(mood, height = h * 0.6f)

        if (mood == SceneMood.Night) {
            // crescent moon, high in the sky
            val d = w * 0.16f
            drawMoon(center = Offset(w * 0.78f, h * 0.16f - drift * 4 * density), diameter = d, color = mood.sun)
        } else {
            // sun sitting on the horizon, half behind the dunes
            val r = w * 0.15f
            val c = Offset(w * 0.70f, h * (1 - duneHeight * 0.92f) + drift * 5 * density)
            drawCircle(Brush.radialGradient(listOf(mood.sun.copy(alpha = 0.55f), Color.Transparent), c, r * 1.9f), r * 1.9f, c)
            drawCircle(mood.sun, r, c)
        }

        drawDune(Rect(0f, h - h * duneHeight * 1.05f, w, h), phase = 0.15f, amplitude = 0.30f, color = mood.dunes[0])
        val palmW = w * 0.22f
        val palmH = h * duneHeight * 0.95f
        val palmTopLeft = Offset(w * 0.18f - palmW / 2, h * (1 - duneHeight * 0.78f) - palmH / 2)
        drawPalm(Rect(palmTopLeft, Size(palmW, palmH)), mood.dunes[0].copy(alpha = 0.9f))
        drawDune(Rect(0f, h - h * duneHeight * 0.8f, w, h), phase = 0.55f, amplitude = 0.35f, color = mood.dunes[1])
        drawDune(Rect(0f, h - h * duneHeight * 0.55f, w, h), phase = 0.9f, amplitude = 0.25f, color = mood.dunes[2])
    }
}

/** 70 fixed stars in the upper sky. */
private fun DrawScope.drawStars(alpha: Float) {
    val rng = SeededRng("stars")
    repeat(70) {
        val x = (rng.next() % 1000uL).toFloat() / 1000 * size.width
        val y = (rng.next() % 1000uL).toFloat() / 1000 * size.height * 0.6f
        val s = ((rng.next() % 100uL).toFloat() / 100 * 2 + 0.6f) * density
        drawCircle(Color.White.copy(alpha = 0.85f * alpha), s / 2, Offset(x + s / 2, y + s / 2))
    }
}

private fun DrawScope.drawMoon(center: Offset, diameter: Float, color: Color) {
    val full = Path().apply { addOval(Rect(center, diameter / 2)) }
    // the bite is shifted toward the screen's left (mirrored like the rest of the scene)
    val bite = Path().apply {
        addOval(Rect(Offset(center.x - diameter * 0.31f, center.y - diameter * 0.19f), diameter * 0.47f))
    }
    drawCircle(Brush.radialGradient(listOf(color.copy(alpha = 0.5f), Color.Transparent), center, diameter), diameter, center)
    drawPath(Path.combine(PathOperation.Difference, full, bite), color)
}

/** A smooth dune line across the top of [r]. */
private fun DrawScope.drawDune(r: Rect, phase: Float, amplitude: Float, color: Color) {
    val top = r.top + r.height * amplitude
    val p = Path().apply {
        moveTo(r.left, r.bottom)
        lineTo(r.left, top + r.height * 0.15f * sin(phase * 6))
        val steps = 3
        for (i in 1..steps) {
            val x = r.left + r.width * i / steps
            val y = top + r.height * 0.18f * sin(phase * 6 + i * 1.9f)
            val cx = x - r.width / steps / 2
            val cy = top - r.height * amplitude * 0.9f * (if (i % 2 == 0) 0.4f else 1f)
            quadraticTo(cx, cy, x, y)
        }
        lineTo(r.right, r.bottom)
        close()
    }
    drawPath(p, color)
}

/** Date-palm silhouette: curved trunk and seven fronds. */
private fun DrawScope.drawPalm(r: Rect, color: Color) {
    val midX = r.center.x
    val midY = r.center.y
    val base = Offset(midX, r.bottom)
    val top = Offset(midX + r.width * 0.08f, r.top + r.height * 0.22f)
    val p = Path().apply {
        moveTo(base.x - r.width * 0.035f, base.y)
        quadraticTo(midX - r.width * 0.12f, midY, top.x - r.width * 0.02f, top.y)
        lineTo(top.x + r.width * 0.02f, top.y)
        quadraticTo(midX - r.width * 0.06f, midY, base.x + r.width * 0.035f, base.y)
        close()
        for (deg in listOf(-160f, -130f, -100f, -60f, -30f, -5f, 20f)) {
            val rad = deg * PI.toFloat() / 180
            val len = r.width * 0.55f
            val tip = Offset(top.x + cos(rad) * len, top.y + sin(rad) * len * 0.55f + len * 0.25f)
            val ctrl = Offset(top.x + cos(rad) * len * 0.5f, top.y + sin(rad) * len * 0.6f - len * 0.12f)
            moveTo(top.x, top.y)
            quadraticTo(ctrl.x, ctrl.y, tip.x, tip.y)
            quadraticTo(ctrl.x, ctrl.y + len * 0.12f, top.x, top.y)
        }
    }
    drawPath(p, color)
}

/**
 * Faint girih "star and cross" pattern over the upper sky: eight-pointed stars (never six),
 * each with an octagon at its heart and short bands to its neighbours. Drawn as carved
 * plaster — a light line with a soft dark line under it — fading out toward the dunes.
 */
private fun DrawScope.drawGirih(mood: SceneMood, height: Float) {
    val cell = 58 * density
    val big = cell * 0.40f
    val inner = big * 0.6f
    val core = big * 0.3f
    val light = if (mood == SceneMood.Day) 0.16f else 0.12f

    val pattern = Path()
    var y = 0f
    while (y < height + cell) {
        var x = 0f
        while (x < size.width + cell) {
            for (k in 0 until 16) {                               // star: 16 points, tips on axes and diagonals
                val a = k * PI.toFloat() / 8 - PI.toFloat() / 2
                val rad = if (k % 2 == 0) big else inner
                if (k == 0) pattern.moveTo(x + cos(a) * rad, y + sin(a) * rad) else pattern.lineTo(x + cos(a) * rad, y + sin(a) * rad)
            }
            pattern.close()
            for (k in 0 until 8) {                                // octagon at the heart
                val a = k * PI.toFloat() / 4 + PI.toFloat() / 8
                if (k == 0) pattern.moveTo(x + cos(a) * core, y + sin(a) * core) else pattern.lineTo(x + cos(a) * core, y + sin(a) * core)
            }
            pattern.close()
            pattern.moveTo(x + big, y); pattern.lineTo(x + cell - big, y)     // band to the next star
            pattern.moveTo(x, y + big); pattern.lineTo(x, y + cell - big)     // band to the star below
            x += cell
        }
        y += cell
    }

    // the lines fade out toward the dunes: full strength at the top, gone at `height`
    fun fade(color: Color) = Brush.verticalGradient(
        0f to color, 0.35f to color.copy(alpha = color.alpha * 0.8f), 1f to Color.Transparent, endY = height,
    )
    clipRect(bottom = height) {
        translate(0.6f * density, 1f * density) {
            drawPath(pattern, fade(Color.Black.copy(alpha = light * 0.9f)), style = Stroke(1.2f * density))
        }
        drawPath(pattern, fade(Color.White.copy(alpha = light)), style = Stroke(1f * density))
    }
}
