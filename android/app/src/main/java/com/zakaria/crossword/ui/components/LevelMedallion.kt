package com.zakaria.crossword.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.ui.theme.NumberText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.arNum

/** A level on the levels path: locked, open, or solved with its stars. */
sealed interface MedallionState {
    data object Locked : MedallionState
    data object Open : MedallionState
    data class Solved(val stars: Int) : MedallionState
}

@Composable
fun LevelMedallion(number: Int, state: MedallionState, isNext: Boolean, modifier: Modifier = Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(contentAlignment = Alignment.Center) {
            if (isNext) NextGlow()
            val tile = Modifier.width(64.dp).height(68.dp)
            when (state) {
                MedallionState.Locked -> Tile3D(listOf(Color(0xFFCFC4B2), Color(0xFFB7AA94)), Color(0xFF857760), tile, 32.dp) {
                    GameIcon(Icons.Filled.Lock, Color.White.copy(alpha = 0.9f), size = 22.dp)
                }
                MedallionState.Open -> Tile3D(listOf(Palette.buttonLight, Palette.buttonShade), Palette.buttonEdge, tile, 32.dp) {
                    NumberText(arNum(number), 24.sp, Color.White)
                }
                is MedallionState.Solved -> Tile3D(listOf(Palette.goldLight, Palette.goldShade), Palette.goldEdge, tile, 32.dp) {
                    NumberText(arNum(number), 24.sp, Palette.onGold)
                }
            }
        }
        if (state is MedallionState.Solved) StarsRow(state.stars, 13.dp) else Spacer(Modifier.height(15.dp))
    }
}

/** Soft pulsing gold halo behind the level to play next. */
@Composable
private fun NextGlow() {
    val pulse by rememberInfiniteTransition(label = "glow").animateFloat(
        0.92f, 1.12f, infiniteRepeatable(tween(1000), RepeatMode.Reverse), label = "scale",
    )
    Box(
        Modifier
            .size(86.dp)
            .graphicsLayer { scaleX = pulse; scaleY = pulse }
            .blur(6.dp)
            .background(Palette.gold.copy(alpha = 0.6f), CircleShape),
    )
}
