package com.zakaria.crossword.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.LocalCafe
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Science
import androidx.compose.material.icons.filled.SportsSoccer
import androidx.compose.material.icons.filled.WbTwilight
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Radius
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.TextSize

/** Cream card with a gold border and a soft shadow. */
@Composable
fun Panel(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    val shape = RoundedCornerShape(Radius.card)
    Box(
        modifier
            .shadow(10.dp, shape)
            .background(Palette.panel, shape)
            .border(1.5.dp, Palette.gold.copy(alpha = 0.9f), shape),
        content = content,
    )
}

/** How a clue category is labelled. */
data class Category(val name: String, val icon: ImageVector, val color: Color) {
    companion object {
        fun of(id: String): Category = when (id) {
            "gulf" -> Category("الخليج", Icons.Filled.WbTwilight, Color(0xFFA5552A))
            "geography" -> Category("جغرافيا", Icons.Filled.Public, Color(0xFF1F6E8C))
            "religion" -> Category("ديني", Icons.Filled.NightsStay, Color(0xFF2E6B4F))
            "sport" -> Category("رياضة", Icons.Filled.SportsSoccer, Color(0xFF3F51A0))
            "science" -> Category("علوم", Icons.Filled.Science, Color(0xFF6A3FA0))
            "language" -> Category("لغة", Icons.AutoMirrored.Filled.MenuBook, Color(0xFF8C2F39))
            "food" -> Category("مأكولات", Icons.Filled.LocalCafe, Color(0xFF8A5A00))
            "history" -> Category("تاريخ", Icons.Filled.AccountBalance, Color(0xFF5A4632))
            "flags" -> Category("أعلام", Icons.Filled.Flag, Color(0xFFB3261E))
            else -> Category("معلومات عامة", Icons.Filled.Lightbulb, Color(0xFF5A4632))
        }
    }
}

/** The open word's clue with its category tag. */
@Composable
fun ClueCard(category: String, clue: String, modifier: Modifier = Modifier) {
    val cat = Category.of(category)
    Panel(modifier.fillMaxWidth()) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(vertical = Space.md, horizontal = Space.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.sm),
        ) {
            Row(
                Modifier
                    .background(cat.color, CircleShape)
                    .padding(horizontal = Space.md, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                GameIcon(cat.icon, Color.White, size = 15.dp)
                ArabicText(cat.name, TextSize.caption, Color.White)
            }
            ArabicText(clue, TextSize.clue, Palette.panelText, align = TextAlign.Center, maxLines = 3)
        }
    }
}

/** Gold progress bar. */
@Composable
fun ProgressBar(fraction: Float, modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxWidth()
            .height(10.dp)
            .background(Color.Black.copy(alpha = 0.15f), CircleShape),
    ) {
        if (fraction > 0f) {
            Box(
                Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(fraction.coerceIn(0.05f, 1f))
                    .background(Brush.verticalGradient(listOf(Palette.goldLight, Palette.goldShade)), CircleShape),
            )
        }
    }
}

/** Short pill of text over a scene. */
@Composable
fun Pill(text: String, modifier: Modifier = Modifier, size: TextUnit = TextSize.caption) {
    ArabicText(
        text, size, Color.White,
        modifier = modifier
            .background(Palette.coinPill.copy(alpha = 0.6f), CircleShape)
            .padding(horizontal = Space.md, vertical = 4.dp),
        align = TextAlign.Center,
    )
}
