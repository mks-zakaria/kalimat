package com.zakaria.crossword.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Design tokens — the same values as the iOS app (replica/design/tokens.json, v2 game look).
 * Change a value there first, re-run the contrast check, then here and in Theme.swift.
 */
object Palette {
    // text and states
    val text = Color(0xFF1E2230)
    val textMuted = Color(0xFF5F6573)
    val accent = Color(0xFF8C2F39)
    val danger = Color(0xFFB3261E)
    val success = Color(0xFF2E6B4F)

    // game look
    val panel = Color(0xFFFFF8EC)
    val panelText = Color(0xFF2B1D12)
    val panelMuted = Color(0xFF6B5A48)
    val tile = Color(0xFFFFF6E6)
    val tileShade = Color(0xFFF1E2C6)
    val tileEdge = Color(0xFF9C7E52)
    val tileText = Color(0xFF2B1D12)
    val gold = Color(0xFFF2C55C)
    val goldLight = Color(0xFFFFD978)
    val goldShade = Color(0xFFE2A93E)
    val goldEdge = Color(0xFFB9862E)
    val onGold = Color(0xFF2B1D12)
    val turquoise = Color(0xFF187770)
    val turquoiseLight = Color(0xFF24A096)
    val turquoiseEdge = Color(0xFF0E4F4A)
    val onTurquoise = Color.White
    val button = Color(0xFF9E3440)
    val buttonLight = Color(0xFFB8434F)
    val buttonShade = Color(0xFF7E2731)
    val buttonEdge = Color(0xFF5C1B23)
    val onButton = Color.White
    val slot = Color(0xFFEDE0C8)
    val coinPill = Color(0xFF2B1D12)
}

/** Corner radii. */
object Radius {
    val cell = 8.dp
    val key = 12.dp
    val card = 22.dp
}

/** Spacing and fixed sizes. */
object Space {
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 24.dp
    val xxl = 32.dp
    val cellMax = 44.dp
    val cellGap = 4.dp
    val key = 46.dp
    val slot = 44.dp
    val topBar = 52.dp
    val edge = 4.dp          // height of a tile's 3D bottom edge
}
