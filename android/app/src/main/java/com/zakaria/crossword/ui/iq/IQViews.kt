package com.zakaria.crossword.ui.iq

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.outlined.Info
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.LocalApp
import com.zakaria.crossword.game.IQResult
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds
import com.zakaria.crossword.ui.components.GameIcon
import com.zakaria.crossword.ui.components.pressable
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.NumberText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Radius
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.TextSize
import com.zakaria.crossword.ui.theme.arNum
import kotlinx.coroutines.delay
import kotlin.math.abs

/** Counts a number from [from] to [to] one step at a time (about one second in all), then calls [onDone]. */
@Composable
fun IQCounter(from: Int, to: Int, size: TextUnit, color: Color, delayMs: Long = 0, onDone: () -> Unit = {}) {
    var shown by remember { mutableIntStateOf(from) }
    LaunchedEffect(to) {
        shown = from
        if (from != to) {
            delay(delayMs)
            val steps = abs(to - from)
            val pause = (1100L / steps).coerceIn(25, 90)
            repeat(steps) { i ->
                shown = from + (if (to > from) 1 else -1) * (i + 1)
                delay(pause)
            }
        }
        onDone()
    }
    NumberText(arNum(shown), size, color)
}

/** Green "▲ +4" or red "▼ −3" badge. */
@Composable
private fun IQDeltaBadge(delta: Int) {
    val up = delta > 0
    Row(
        Modifier
            .background(if (up) Palette.success else Palette.danger, CircleShape)
            .padding(horizontal = 8.dp, vertical = 3.dp),
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        GameIcon(if (up) Icons.Filled.ArrowUpward else Icons.Filled.ArrowDownward, Color.White, size = 15.dp)
        NumberText((if (up) "+" else "−") + arNum(abs(delta)), 15.sp, Color.White)
    }
}

/**
 * The IQ box on the level-complete card: this level's score, then the overall IQ counting
 * from its old value to the new one with an up/down badge. Tap it for the explanation card.
 */
@Composable
fun IQResultBox(result: IQResult) {
    var counted by remember { mutableStateOf(false) }
    var glow by remember { mutableStateOf(false) }
    var showCard by remember { mutableStateOf(false) }
    val delta = if (result.counted) result.after - (result.before ?: result.after) else 0
    val glowColor = if (delta > 0) Palette.success else Palette.danger
    val scale by animateFloatAsState(if (glow) 1.05f else 1f, label = "glow")
    val border by animateColorAsState(if (glow) glowColor else Color.Transparent, label = "border")
    val shape = RoundedCornerShape(Radius.key)

    LaunchedEffect(glow) {
        if (glow) { delay(900); glow = false }
    }

    Column(
        Modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .background(Palette.turquoise.copy(alpha = 0.1f), shape)
            .border(2.dp, border, shape)
            .pressable { Sounds.play(Sound.Tap); showCard = true }
            .padding(horizontal = Space.lg, vertical = Space.sm),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            GameIcon(Icons.Filled.Psychology, Palette.turquoise)
            ArabicText("ذكاؤك في هذا اللغز: ${arNum(result.level)}", 16.sp, Palette.panelText)
            GameIcon(Icons.Outlined.Info, Palette.panelMuted, size = 14.dp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            val label = when {
                !result.counted -> "معدّلك (إعادة لا تُحتسب)"
                result.before == null -> "أول معدّل لذكائك"
                else -> "معدّل ذكائك"
            }
            ArabicText(label, TextSize.caption, Palette.panelMuted)
            IQCounter(result.before ?: result.after, result.after, 28.sp, Palette.panelText, delayMs = 1500) {
                counted = true
                if (delta != 0) {
                    Sounds.play(if (delta > 0) Sound.Star else Sound.Undo)
                    glow = true
                }
            }
            AnimatedVisibility(counted && delta != 0, enter = scaleIn(spring(dampingRatio = 0.55f)) + fadeIn()) {
                IQDeltaBadge(delta)
            }
        }
    }
    if (showCard) IQCard(onClose = { showCard = false })
}

/** Last IQ value the home button showed while the app was open, so a change can count up. */
private object IQButtonMemory {
    var lastShown: Int? = null
}

/**
 * Home: the player's IQ. When it changed since it was last on screen, it counts to the new
 * value with a green or red pulse. Tap it for the explanation card.
 */
@Composable
fun IQButton() {
    val store = LocalApp.current.store
    val iq = store.iq
    val from = remember { IQButtonMemory.lastShown ?: iq }
    var delta by remember { mutableIntStateOf(0) }
    var showCard by remember { mutableStateOf(false) }
    val pulse = delta != 0
    val scale by animateFloatAsState(if (pulse) 1.12f else 1f, spring(dampingRatio = 0.45f), label = "pulse")
    val background = if (!pulse) Palette.turquoise else if (delta > 0) Palette.success else Palette.danger

    LaunchedEffect(delta) {
        if (delta != 0) { delay(1400); delta = 0 }
    }

    Row(
        Modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .background(background.copy(alpha = 0.9f), CircleShape)
            .border(1.dp, Color.White.copy(alpha = 0.4f), CircleShape)
            .pressable { Sounds.play(Sound.Tap); showCard = true }
            .padding(horizontal = Space.lg, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        GameIcon(Icons.Filled.Psychology, Color.White)
        if (iq == null) {
            ArabicText("اكتشف معدّل ذكائك", 16.sp, Color.White)
        } else {
            ArabicText("معدّل ذكائك", 16.sp, Color.White)
            IQCounter(from ?: iq, iq, 18.sp, Color.White, delayMs = 450) {
                val d = iq - (from ?: iq)
                IQButtonMemory.lastShown = iq
                if (d != 0) {
                    Sounds.play(if (d > 0) Sound.Star else Sound.Undo)
                    delta = d
                }
            }
        }
        if (pulse) {
            GameIcon(
                if (delta > 0) Icons.Filled.ArrowUpward else Icons.Filled.ArrowDownward,
                if (delta > 0) Color(0xFFB9F6CA) else Color(0xFFFFCDD2), size = 16.dp,
            )
        }
    }
    if (showCard) IQCard(onClose = { showCard = false })
}
