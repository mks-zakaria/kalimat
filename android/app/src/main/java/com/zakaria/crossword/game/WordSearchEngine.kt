package com.zakaria.crossword.game

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.zakaria.crossword.model.CellPos
import com.zakaria.crossword.model.Entry
import com.zakaria.crossword.model.Level
import com.zakaria.crossword.model.LevelProgress
import java.time.Instant
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sign

/**
 * Rules for one word-search level ("كلمات مخفية"): every answer is hidden in the square and the
 * player draws a straight line over it. The clue is shown, the word is not.
 *
 * Saves through the same [LevelProgress] as the crossword:
 * `solved` = found entry ids; `revealed` = hint marks ("word:<id>", "start:<id>").
 */
class WordSearchEngine(val level: Level, saved: LevelProgress? = null) {
    val puzzle: WordSearchPuzzle = WordSearchGenerator.make(level)

    /** Cells of each found word, as the player drew them. */
    var found by mutableStateOf(mapOf<String, List<CellPos>>()); private set
    var shownWords by mutableStateOf(setOf<String>()); private set     // answer text shown by a hint
    var shownStarts by mutableStateOf(setOf<String>()); private set    // first letter circled by a hint
    var hintsUsed by mutableStateOf(0); private set
    private var completedAt: String? = null

    var onProgress: ((LevelProgress) -> Unit)? = null

    /** What a drawn line turned out to be. */
    sealed interface Result {
        data class Found(val entry: Entry) : Result
        data object Wrong : Result
        data object TooShort : Result
    }

    init {
        if (saved != null) {
            found = saved.solved.mapNotNull { id -> puzzle.placements[id]?.let { id to it.cells } }.toMap()
            shownWords = saved.revealed.filter { it.startsWith("word:") }.map { it.removePrefix("word:") }.toSet()
            shownStarts = saved.revealed.filter { it.startsWith("start:") }.map { it.removePrefix("start:") }.toSet()
            hintsUsed = saved.hintsUsed
            completedAt = saved.completedAt
        }
    }

    val isComplete: Boolean get() = found.size == level.entries.size
    val stars: Int get() = GameEngine.starsFor(isComplete, hintsUsed)
    fun isFound(e: Entry): Boolean = e.id in found
    val firstUnfound: Entry? get() = level.entries.firstOrNull { !isFound(it) }

    /**
     * Checks a drawn line. Accepted in either drawing direction; the letters must spell an
     * answer not found yet (an answer may also be found where it appears by chance).
     */
    fun select(cells: List<CellPos>): Result {
        if (cells.size < 2) return Result.TooShort
        val drawn = cells.map { puzzle.letter(it) }
        val reversed = drawn.reversed()
        val open = level.entries.filter { !isFound(it) }

        // Some answers are other answers backwards (سوق / قوس): prefer the word hidden at
        // exactly these cells, then a forward reading, then a backward one.
        val here = cells.toSet()
        val e = open.firstOrNull { puzzle.placements[it.id]?.cells?.toSet() == here }
            ?: open.firstOrNull { WordSearchGenerator.letters(it) == drawn }
            ?: open.firstOrNull { WordSearchGenerator.letters(it) == reversed }
            ?: return Result.Wrong

        found = found + (e.id to cells)
        if (isComplete && completedAt == null) completedAt = Instant.now().toString()
        save()
        return Result.Found(e)
    }

    // ---- hints (the caller pays first) ----

    fun canShowWord(e: Entry): Boolean = !isFound(e) && e.id !in shownWords
    fun canShowStart(e: Entry): Boolean = !isFound(e) && e.id !in shownStarts
    fun startCell(e: Entry): CellPos? = puzzle.placements[e.id]?.start

    fun showWord(e: Entry) {
        if (!canShowWord(e)) return
        shownWords = shownWords + e.id
        hintsUsed += 1
        save()
    }

    fun showStart(e: Entry) {
        if (!canShowStart(e)) return
        shownStarts = shownStarts + e.id
        hintsUsed += 1
        save()
    }

    fun snapshot(): LevelProgress = LevelProgress(
        solved = level.entries.map { it.id }.filter { it in found },
        revealed = shownWords.sorted().map { "word:$it" } + shownStarts.sorted().map { "start:$it" },
        hintsUsed = hintsUsed,
        stars = stars,
        completedAt = completedAt,
    )

    private fun save() {
        onProgress?.invoke(snapshot())
    }

    companion object {
        /** Cells on the straight line from [a] to [b] (8 directions), or null if it is not straight. */
        fun line(a: CellPos, b: CellPos): List<CellPos>? {
            val dr = b.row - a.row
            val dc = b.col - a.col
            if (dr != 0 && dc != 0 && abs(dr) != abs(dc)) return null
            val n = max(abs(dr), abs(dc))
            return (0..n).map { CellPos(a.row + dr.sign * it, a.col + dc.sign * it) }
        }
    }
}
