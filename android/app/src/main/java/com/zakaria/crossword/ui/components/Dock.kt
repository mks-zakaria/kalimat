package com.zakaria.crossword.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.dp
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Space

/** The cream panel at the bottom of a game screen (clue, hints, keys). */
@Composable
fun Dock(content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(16.dp, shape)
            .background(Palette.panel.copy(alpha = 0.97f), shape)
            .navigationBarsPadding()
            .padding(Space.md)
            .padding(bottom = Space.sm),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.md),
        content = content,
    )
}
