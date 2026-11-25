package com.zakaria.crossword.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.ui.theme.NumberText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.TextSize
import com.zakaria.crossword.ui.theme.arNum

/** A gold coin drawn in code (no image files). */
@Composable
fun CoinIcon(size: Dp = 20.dp) {
    Canvas(Modifier.size(size)) {
        val r = this.size.minDimension / 2
        drawCircle(Brush.linearGradient(listOf(Color(0xFFFFE08A), Palette.goldShade), Offset.Zero, Offset(r * 2, r * 2)))
        drawCircle(Palette.goldEdge, radius = r - r * 0.1f, style = Stroke(width = r * 0.2f))
        drawCircle(Color(0xFFFFF1C2), radius = r * 0.56f, style = Stroke(width = 1.dp.toPx()))
    }
}

/** Small price tag: coin + amount. */
@Composable
fun CoinChip(amount: Int) {
    Row(
        Modifier
            .background(Palette.gold.copy(alpha = 0.35f), CircleShape)
            .padding(horizontal = 8.dp, vertical = 3.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CoinIcon(14.dp)
        NumberText(arNum(amount), 14.sp, Palette.onGold)
    }
}

/** The coin counter shown in every top bar. */
@Composable
fun CoinBadge(coins: Int, modifier: Modifier = Modifier) {
    Row(
        modifier
            .height(36.dp)
            .background(Palette.coinPill.copy(alpha = 0.75f), CircleShape)
            .border(1.5.dp, Palette.gold.copy(alpha = 0.8f), CircleShape)
            .padding(start = 6.dp, end = 12.dp)
            .clearAndSetSemantics { contentDescription = "العملات ${arNum(coins)}" },
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CoinIcon(22.dp)
        NumberText(arNum(coins), TextSize.number, Color.White)
    }
}

/** Three stars, the first [stars] of them gold. */
@Composable
fun StarsRow(stars: Int, size: Dp = 14.dp) {
    Row(
        Modifier.clearAndSetSemantics { contentDescription = "${arNum(stars)} نجوم" },
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        repeat(3) { i ->
            GameIcon(Icons.Filled.Star, if (i < stars) Palette.gold else Color.Black.copy(alpha = 0.2f), size = size)
        }
    }
}
