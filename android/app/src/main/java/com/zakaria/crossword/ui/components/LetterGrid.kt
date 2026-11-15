package com.zakaria.crossword.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.absoluteOffset
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotateRad
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.game.WordSearchEngine
import com.zakaria.crossword.game.WordSearchPuzzle
import com.zakaria.crossword.model.CellPos
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Radius
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

private val bandColors = listOf(
    Color(0xFF2A9D8F), Color(0xFFE76F51), Color(0xFF6A4C93), Color(0xFFE9A23B),
    Color(0xFF3D7DCA), Color(0xFFC2185B), Color(0xFF558B2F), Color(0xFF8D6E63),
)

/**
 * The word-search square. Draw a straight line over a word, or tap its first letter then its last.
 *
 * Laid out in absolute (left-to-right) screen coordinates with column 0 on the RIGHT,
 * so a word placed "across" reads right to left as Arabic does.
 */
@Composable
fun LetterGrid(
    puzzle: WordSearchPuzzle,
    found: Map<String, List<CellPos>>,
    hintStarts: Set<CellPos>,
    side: Dp,
    onSelect: (List<CellPos>) -> Unit,
    modifier: Modifier = Modifier,
) {
    val n = puzzle.size
    val cellDp = side / n
    val cellPx = with(LocalDensity.current) { cellDp.toPx() }

    var dragStart by remember { mutableStateOf<CellPos?>(null) }
    var dragEnd by remember { mutableStateOf<CellPos?>(null) }
    var tapStart by remember { mutableStateOf<CellPos?>(null) }

    fun center(c: CellPos) = Offset((n - 1 - c.col + 0.5f) * cellPx, (c.row + 0.5f) * cellPx)

    fun cellAt(p: Offset) = CellPos(
        row = (p.y / cellPx).toInt().coerceIn(0, n - 1),
        col = n - 1 - (p.x / cellPx).toInt().coerceIn(0, n - 1),
    )

    /** Snaps the finger to the nearest of the 8 straight directions, clipped to the grid. */
    fun snapped(from: CellPos, p: Offset): CellPos {
        val o = center(from)
        val dx = p.x - o.x
        val dy = p.y - o.y
        if (hypot(dx, dy) <= cellPx * 0.35f) return from
        val step = (atan2(dy, dx) / (PI / 4)).roundToInt()                // -4..4
        val screenSteps = listOf(1 to 0, 1 to 1, 0 to 1, -1 to 1, -1 to 0, -1 to -1, 0 to -1, 1 to -1)
        val (sx, sy) = screenSteps[(step + 8) % 8]
        var len = (max(abs(dx), abs(dy)) / cellPx).roundToInt()
        while (len > 0) {
            val r = from.row + sy * len
            val c = from.col - sx * len                                     // screen x grows leftward in columns
            if (r in 0 until n && c in 0 until n) return CellPos(r, c)
            len--
        }
        return from
    }

    /** Tap the first letter, then the last: same as drawing the line. */
    fun tap(c: CellPos) {
        val a = tapStart
        if (a == null) { tapStart = c; return }
        tapStart = null
        if (a != c) {
            val line = WordSearchEngine.line(a, c)
            if (line != null) onSelect(line) else tapStart = c
        }
    }

    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        val shape = RoundedCornerShape(Radius.card)
        Box(
            modifier
                .size(side)
                .shadow(10.dp, shape)
                .background(Palette.panel, shape)
                .border(2.dp, Palette.gold, shape)
                .pointerInput(puzzle) {
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        val a = cellAt(down.position)
                        dragStart = a
                        Sounds.play(Sound.Key)
                        var last = down.position
                        do {
                            val event = awaitPointerEvent()
                            val change = event.changes.firstOrNull() ?: break
                            last = change.position
                            dragEnd = snapped(a, last).takeIf { it != a }
                            change.consume()
                        } while (change.pressed)

                        val moved = (last - down.position).getDistance() > cellPx * 0.45f
                        val end = dragEnd
                        dragStart = null
                        dragEnd = null
                        val line = if (moved && end != null) WordSearchEngine.line(a, end) else null
                        if (line != null) {
                            tapStart = null
                            onSelect(line)
                        } else {
                            tap(a)
                        }
                    }
                },
        ) {
            Canvas(Modifier.fillMaxSize()) {
                // found words: one coloured band each
                found.keys.sorted().forEachIndexed { i, id ->
                    val cells = found.getValue(id)
                    drawBand(center(cells.first()), center(cells.last()), cellPx, bandColors[i % bandColors.size].copy(alpha = 0.42f))
                }
                // the line being drawn (or the first tap)
                (dragStart ?: tapStart)?.let { a ->
                    drawBand(center(a), center(dragEnd ?: a), cellPx, Palette.gold.copy(alpha = 0.6f))
                }
                // hint: a ring round the first letter of a word
                for (c in hintStarts) {
                    drawCircle(Palette.turquoise, cellPx * 0.43f, center(c), style = Stroke(3.dp.toPx()))
                }
            }
            for (r in 0 until n) for (c in 0 until n) {
                val cell = CellPos(r, c)
                Box(
                    Modifier
                        .absoluteOffset(x = cellDp * (n - 1 - c), y = cellDp * r)
                        .size(cellDp),
                    contentAlignment = Alignment.Center,
                ) {
                    ArabicText(puzzle.letter(cell), min(30f, cellDp.value * 0.56f).sp, Palette.tileText)
                }
            }
        }
    }
}

/** A rounded band from the centre of one cell to the centre of another. */
private fun DrawScope.drawBand(p: Offset, q: Offset, cell: Float, color: Color) {
    val thickness = cell * 0.82f
    val length = (q - p).getDistance() + thickness
    val mid = (p + q) / 2f
    rotateRad(atan2(q.y - p.y, q.x - p.x), pivot = mid) {
        drawRoundRect(
            color,
            topLeft = Offset(mid.x - length / 2, mid.y - thickness / 2),
            size = Size(length, thickness),
            cornerRadius = CornerRadius(thickness / 2),
        )
    }
}
