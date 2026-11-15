package com.zakaria.crossword.ui.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.model.CellPos
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Radius
import com.zakaria.crossword.ui.theme.Space

// ---------------------------------------------------------------- crossword grid

enum class CellState { Empty, Active, Hint, Solved }

/** One square of the crossword. */
@Composable
fun GridCell(letter: String?, state: CellState, size: Dp, isCursor: Boolean, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(Radius.cell)
    val fontSize = (size.value * 0.56f).sp
    when (state) {
        CellState.Empty, CellState.Active -> {
            val active = state == CellState.Active
            Box(
                modifier
                    .size(size)
                    .shadow(if (active) 6.dp else 2.dp, shape, ambientColor = if (active) Palette.gold else Color.Black)
                    .background(if (active) Color(0xFFFFE9B8) else Color.White.copy(alpha = 0.92f), shape)
                    .border(
                        width = if (isCursor) 3.dp else if (active) 2.dp else 1.dp,
                        color = if (isCursor) Palette.button else if (active) Palette.goldEdge else Palette.tileEdge.copy(alpha = 0.5f),
                        shape = shape,
                    ),
                contentAlignment = Alignment.Center,
            ) { ArabicText(letter ?: "", fontSize, Palette.tileText) }
        }
        CellState.Hint -> Tile3D(
            listOf(Palette.turquoiseLight, Palette.turquoise), Palette.turquoiseEdge, modifier.size(size), Radius.cell, 3.dp,
        ) { ArabicText(letter ?: "", fontSize, Palette.onTurquoise) }
        CellState.Solved -> Tile3D(
            listOf(Palette.gold, Palette.goldShade), Palette.goldEdge, modifier.size(size), Radius.cell, 3.dp,
        ) { ArabicText(letter ?: "", fontSize, Palette.onGold) }
    }
}

/**
 * The crossword. Only cells listed in [states] are drawn; the others are empty space.
 * Column 0 is the rightmost: in the app's right-to-left layout a Row starts on the right.
 */
@Composable
fun CrosswordBoard(
    rows: Int,
    cols: Int,
    letters: Map<CellPos, String>,
    states: Map<CellPos, CellState>,
    cellSize: Dp,
    cursor: CellPos?,
    onTap: (CellPos) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(Space.cellGap)) {
        for (r in 0 until rows) {
            Row(horizontalArrangement = Arrangement.spacedBy(Space.cellGap)) {
                for (c in 0 until cols) {
                    val cell = CellPos(r, c)
                    val state = states[cell]
                    if (state == null) {
                        Spacer(Modifier.size(cellSize))
                    } else {
                        GridCell(
                            letters[cell], state, cellSize, isCursor = cursor == cell,
                            modifier = Modifier
                                .semantics { contentDescription = letters[cell] ?: "خانة فارغة" }
                                .pressable { onTap(cell) },
                        )
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------- answer slots

enum class SlotState { Empty, Typed, Revealed, Wrong, Solved }

/** The open word's letters, one slot each; tapping a typed letter gives it back. */
@Composable
fun AnswerSlots(letters: List<String?>, states: List<SlotState>, onTap: (Int) -> Unit, modifier: Modifier = Modifier) {
    val size = if (letters.size > 7) 36.dp else Space.slot
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        letters.forEachIndexed { i, letter ->
            Slot(letter, states[i], size, Modifier.pressable(enabled = states[i] == SlotState.Typed) { onTap(i) })
        }
    }
}

@Composable
private fun Slot(letter: String?, state: SlotState, size: Dp, modifier: Modifier) {
    val text = letter ?: ""
    val fontSize = (size.value * 0.56f).sp
    val tileModifier = modifier.width(size).height(size + 3.dp)
    when (state) {
        SlotState.Solved -> Tile3D(listOf(Palette.gold, Palette.goldShade), Palette.goldEdge, tileModifier, Radius.cell, 3.dp) {
            ArabicText(text, fontSize, Palette.onGold)
        }
        SlotState.Revealed -> Tile3D(listOf(Palette.turquoiseLight, Palette.turquoise), Palette.turquoiseEdge, tileModifier, Radius.cell, 3.dp) {
            ArabicText(text, fontSize, Palette.onTurquoise)
        }
        SlotState.Typed -> Tile3D(listOf(Palette.tile, Palette.tileShade), Palette.tileEdge, tileModifier, Radius.cell, 3.dp) {
            ArabicText(text, fontSize, Palette.tileText)
        }
        SlotState.Empty, SlotState.Wrong -> {
            val shape = RoundedCornerShape(Radius.cell)
            val wrong = state == SlotState.Wrong
            Box(
                modifier
                    .padding(bottom = 3.dp)
                    .size(size)
                    .background(Palette.slot, shape)
                    .border(if (wrong) 2.5.dp else 1.dp, if (wrong) Palette.danger else Palette.tileEdge.copy(alpha = 0.6f), shape),
            )
        }
    }
}

// ---------------------------------------------------------------- letter keys

enum class KeyState { Normal, Used, Removed }

/** One key of the letter bank. A removed key shrinks away but keeps its place. */
@Composable
fun LetterKey(letter: String, state: KeyState, onClick: () -> Unit, size: Dp = Space.key) {
    val scale by animateFloatAsState(
        if (state == KeyState.Removed) 0.4f else 1f,
        spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMediumLow), label = "key",
    )
    val modifier = Modifier
        .width(size)
        .height(size + Space.edge)
        .graphicsLayer { scaleX = scale; scaleY = scale; alpha = if (state == KeyState.Removed) 0f else 1f }
        .semantics { contentDescription = letter }
        .pressable(enabled = state == KeyState.Normal, onClick = onClick)
    val fontSize = (size.value * 0.56f).sp

    if (state == KeyState.Used) {
        Box(modifier, contentAlignment = Alignment.BottomCenter) {
            Box(
                Modifier
                    .size(size)
                    .background(Palette.slot.copy(alpha = 0.6f), RoundedCornerShape(Radius.key)),
                contentAlignment = Alignment.Center,
            ) { ArabicText(letter, fontSize, Palette.panelMuted.copy(alpha = 0.6f)) }
        }
    } else {
        Tile3D(listOf(Palette.tile, Palette.tileShade), Palette.tileEdge, modifier) {
            ArabicText(letter, fontSize, Palette.tileText)
        }
    }
}
