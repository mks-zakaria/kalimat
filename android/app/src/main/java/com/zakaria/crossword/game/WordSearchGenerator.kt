package com.zakaria.crossword.game

import com.zakaria.crossword.model.CellPos
import com.zakaria.crossword.model.Entry
import com.zakaria.crossword.model.Level
import kotlin.math.ceil
import kotlin.math.sqrt

/** Where one answer is hidden: first cell, step (dr, dc) and length. */
data class Placement(val entryId: String, val start: CellPos, val dr: Int, val dc: Int, val length: Int) {
    val cells: List<CellPos> get() = List(length) { CellPos(start.row + dr * it, start.col + dc * it) }
}

/** A square of letters. grid[row][col]; column 0 is the RIGHTMOST column. */
class WordSearchPuzzle(val size: Int, val grid: List<List<String>>, val placements: Map<String, Placement>) {
    fun letter(c: CellPos): String = grid[c.row][c.col]
}

/** Builds the letter square for a level. Same seed and steps as the iOS app → same grid. */
object WordSearchGenerator {
    /** (dr, dc) with column 0 on the right: (0,1) reads right-to-left like Arabic,
     *  (1,0) top to bottom, (1,1) and (1,-1) the two downward diagonals. */
    private val directions = listOf(0 to 1, 1 to 0, 1 to 1, 1 to -1)

    /** Filler letters, weighted toward common ones so the grid looks like Arabic text. */
    private val filler = "اااللليييوووممنننررتتببههعكدسقفجحخشصطزذثغضظأإة".map { it.toString() }

    fun letters(e: Entry): List<String> = ArabicText.normalise(e.answer).map { it.toString() }

    fun make(level: Level): WordSearchPuzzle {
        val words = level.entries.map { it.id to letters(it) }.sortedByDescending { it.second.size }
        val total = words.sumOf { it.second.size }
        val longest = words.maxOfOrNull { it.second.size } ?: 4
        var size = minOf(10, maxOf(6, longest, ceil(sqrt(total * 1.9)).toInt()))
        val rng = SeededRng("ws:" + level.id)

        while (true) {
            repeat(40) {
                attempt(words, size, rng)?.let { return it }
            }
            size += 1            // the words did not fit: give them more room
        }
    }

    /** Places the words one by one (longest first) at their best-scoring spot, or gives up. */
    private fun attempt(words: List<Pair<String, List<String>>>, size: Int, rng: SeededRng): WordSearchPuzzle? {
        val grid = MutableList(size) { MutableList(size) { "" } }
        val placements = mutableMapOf<String, Placement>()
        val dirUse = IntArray(directions.size)

        for ((id, w) in words) {
            var best: Placement? = null
            var bestScore = Int.MIN_VALUE
            for ((di, d) in directions.withIndex()) {
                val (dr, dc) = d
                for (r in 0 until size) for (c in 0 until size) {
                    val endR = r + dr * (w.size - 1)
                    val endC = c + dc * (w.size - 1)
                    if (endR !in 0 until size || endC !in 0 until size) continue

                    var overlaps = 0
                    var fits = true
                    for (i in w.indices) {
                        val cell = grid[r + dr * i][c + dc * i]
                        if (cell.isEmpty()) continue
                        if (cell == w[i]) overlaps++ else { fits = false; break }
                    }
                    if (!fits || overlaps >= w.size) continue

                    // favour unused directions (variety) and a little sharing of letters
                    val score = overlaps * 2 - dirUse[di] * 3 + rng.nextInt(0..4)
                    if (score > bestScore) {                      // first best wins, like Swift's max(by:)
                        bestScore = score
                        best = Placement(id, CellPos(r, c), dr, dc, w.size)
                    }
                }
            }
            val chosen = best ?: return null
            chosen.cells.forEachIndexed { i, cell -> grid[cell.row][cell.col] = w[i] }
            placements[id] = chosen
            dirUse[directions.indexOf(chosen.dr to chosen.dc)]++
        }
        for (r in 0 until size) for (c in 0 until size) {
            if (grid[r][c].isEmpty()) grid[r][c] = rng.pick(filler)
        }
        return WordSearchPuzzle(size, grid, placements)
    }
}
