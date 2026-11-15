package com.zakaria.crossword.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** A Material icon in one colour (the game does not use the Material theme). */
@Composable
fun GameIcon(icon: ImageVector, tint: Color, modifier: Modifier = Modifier, size: Dp = 20.dp) {
    Image(icon, contentDescription = null, modifier = modifier.size(size), colorFilter = ColorFilter.tint(tint))
}
