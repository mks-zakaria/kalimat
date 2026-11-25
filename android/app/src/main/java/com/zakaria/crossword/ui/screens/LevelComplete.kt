package com.zakaria.crossword.ui.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Star
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.model.Level
import com.zakaria.crossword.model.Pack
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds
import com.zakaria.crossword.ui.components.CoinIcon
import com.zakaria.crossword.ui.components.Confetti
import com.zakaria.crossword.ui.components.GameButton
import com.zakaria.crossword.ui.components.GameIcon
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.NumberText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.TextSize
import com.zakaria.crossword.ui.theme.arNum
import kotlinx.coroutines.delay

/** The level after [level] in its pack, or null after the last one. */
fun nextLevel(pack: Pack, level: Level): Level? =
    pack.levels.getOrNull(pack.levels.indexOf(level) + 1)

/**
 * S06 — level complete: dimmed screen, confetti, banner, stars popping in one by one,
 * the coin reward and the button to the next level ([next] is null after the last one).
 * [extra] is room for more results (the IQ box).
 */
@Composable
fun LevelComplete(
    stars: Int,
    reward: Int,
    next: Level?,
    onContinue: (Level?) -> Unit,
    extra: @Composable () -> Unit = {},
) {
    val appear = remember { Animatable(0.7f) }
    var shown by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        appear.animateTo(1f, spring(dampingRatio = 0.65f, stiffness = 200f))
    }
    LaunchedEffect(Unit) {
        for (i in 1..stars) {
            delay(if (i == 1) 650 else 380)
            shown = i
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.55f))
            // swallow taps so the board underneath can't be played
            .clickable(remember { MutableInteractionSource() }, null) {},
        contentAlignment = Alignment.Center,
    ) {
        Confetti()
        val shape = RoundedCornerShape(28.dp)
        Column(
            Modifier
                .padding(Space.xl)
                .graphicsLayer {
                    scaleX = appear.value; scaleY = appear.value
                    alpha = ((appear.value - 0.7f) / 0.3f).coerceIn(0f, 1f)
                }
                .shadow(24.dp, shape)
                .background(Palette.panel, shape)
                .border(3.dp, Palette.gold, shape)
                .padding(Space.xl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            ArabicText(
                if (stars == 3) "ممتاز!" else "أحسنت!", 40.sp, Palette.onGold,
                modifier = Modifier
                    .offset(y = (-10).dp)
                    .background(Brush.verticalGradient(listOf(Palette.goldLight, Palette.goldShade)), CircleShape)
                    .border(2.dp, Palette.goldEdge, CircleShape)
                    .padding(horizontal = Space.xxl, vertical = Space.xs),
            )

            Row(horizontalArrangement = Arrangement.spacedBy(Space.md), verticalAlignment = Alignment.CenterVertically) {
                repeat(3) { i -> PoppingStar(lit = i < shown, big = i == 1) }
            }

            ArabicText(
                if (stars == 3) "حللت اللغز بدون أي مساعدة!" else "حلّه بمساعدات أقل لتنال ٣ نجوم",
                TextSize.body, Palette.panelMuted,
            )

            extra()

            if (reward > 0) {
                Row(
                    Modifier
                        .background(Palette.gold.copy(alpha = 0.3f), CircleShape)
                        .padding(horizontal = Space.lg, vertical = Space.xs),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    NumberText("+${arNum(reward)}", 24.sp, Palette.onGold)
                    CoinIcon(26.dp)
                }
            }

            GameButton(
                title = if (next == null) "العودة للمجموعة" else "اللغز التالي",
                icon = if (next == null) Icons.Filled.GridView else Icons.AutoMirrored.Filled.ArrowForward,
                onClick = {
                    Sounds.play(Sound.Tap)
                    onContinue(next)
                },
            )
        }
    }
}

@Composable
private fun PoppingStar(lit: Boolean, big: Boolean) {
    val scale by animateFloatAsState(if (lit) 1f else 0.6f, spring(dampingRatio = 0.45f, stiffness = 300f), label = "star")
    GameIcon(
        Icons.Filled.Star,
        tint = if (lit) Palette.gold else Color.Black.copy(alpha = 0.18f),
        size = if (big) 64.dp else 48.dp,
        modifier = Modifier
            .offset(y = if (big) (-10).dp else 0.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale },
    )
}
