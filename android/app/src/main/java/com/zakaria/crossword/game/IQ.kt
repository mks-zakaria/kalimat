package com.zakaria.crossword.game

import com.zakaria.crossword.model.Entry
import com.zakaria.crossword.model.GameMode
import com.zakaria.crossword.model.Level
import kotlin.math.log2
import kotlin.math.max
import kotlin.math.min

/**
 * "IQ" score — a game score, not a psychometric test (the app says so wherever it is shown).
 *
 * Per level: how fast the player solved it compared with an expected time for that level
 * (number of words, their length and difficulty, the mode), minus a little per hint.
 * On pace = 100, twice as fast = 120, twice as slow = 80, kept within 70..160.
 *
 * Overall: each first completion moves the player's IQ toward the level score. Early levels
 * move it a lot (the first one sets it), later ones less (never below 15 %), so it settles
 * but still follows real improvement. Replays never count: the answers are already known.
 */
object IQ {
    private const val FLOOR = 70.0
    private const val CEILING = 160.0
    private const val POINTS_PER_DOUBLING = 20.0      // twice as fast = +20
    private const val HINT_PENALTY = 5.0
    private const val MIN_WEIGHT = 0.15

    /** Seconds an average player needs for this level. Tune these with real play data. */
    fun expectedSeconds(level: Level, mode: GameMode, gridSize: Int = 8): Double {
        fun perWord(e: Entry): Double {
            val n = ArabicText.normalise(e.answer).length.toDouble()
            val difficulty = when (e.difficulty) { 1 -> 1.0; 2 -> 1.3; 3 -> 1.6; else -> 1.3 }
            return when (mode) {
                GameMode.Crossword -> (8 + 1.5 * n) * difficulty      // read clue, think, type
                GameMode.WordSearch -> (9 + 0.8 * n) * difficulty     // read clue, scan, draw
            }
        }
        val base = level.entries.sumOf { perWord(it) }
        return if (mode == GameMode.WordSearch) base * gridSize / 8 else base
    }

    fun levelScore(expected: Double, actual: Double, hints: Int): Int {
        val t = max(actual, 1.0)
        val raw = 100 + POINTS_PER_DOUBLING * log2(expected / t) - HINT_PENALTY * hints
        return Math.round(min(CEILING, max(FLOOR, raw))).toInt()
    }

    /** New overall IQ after a level, from the old one and how many levels it is based on. */
    fun updated(global: Double?, count: Int, levelScore: Int): Double {
        if (global == null || count <= 0) return levelScore.toDouble()
        val weight = max(MIN_WEIGHT, 1.0 / (count + 1))
        return global + weight * (levelScore - global)
    }
}

/** What the level-complete card shows. */
data class IQResult(
    val level: Int,          // this level's score
    val before: Int?,        // overall IQ before (null on the very first level)
    val after: Int,          // overall IQ now
    val counted: Boolean,    // false for a replay
)
