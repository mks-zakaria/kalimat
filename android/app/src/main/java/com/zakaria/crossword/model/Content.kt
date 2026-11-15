package com.zakaria.crossword.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Bundled, read-only puzzle content. Same JSON as the iOS app (app/src/main/assets/pNN.json here).
 */
@Serializable
data class Pack(
    val id: String,
    @SerialName("title_ar") val titleAr: String,
    val order: Int,
    val region: String,
    val levels: List<Level>,
)

@Serializable
data class Level(
    val id: String,
    val number: Int,
    val width: Int,
    val height: Int,
    val entries: List<Entry>,
)

@Serializable
enum class Direction {
    @SerialName("across") Across,
    @SerialName("down") Down,
}

/** One word of a level: its answer, where it sits on the board and its clue. */
@Serializable
data class Entry(
    val id: String,
    val answer: String,
    val row: Int,
    val col: Int,
    val dir: Direction,
    @SerialName("clue_ar") val clueAr: String,
    val image: String? = null,
    val category: String,
    val difficulty: Int,
) {
    /** The answer split into letters (every Arabic letter is one UTF-16 char). */
    val letters: List<String> get() = answer.map { it.toString() }

    /** Cells in reading order. Column 0 is the RIGHTMOST column (Arabic reads right to left). */
    val cells: List<CellPos>
        get() = List(answer.length) { i ->
            if (dir == Direction.Across) CellPos(row, col + i) else CellPos(row + i, col)
        }
}

/** A square of the board. */
data class CellPos(val row: Int, val col: Int) {
    /** "row,col" — how a cell is written in the save file. */
    val key: String get() = "$row,$col"

    companion object {
        fun fromKey(key: String): CellPos? {
            val parts = key.split(",").mapNotNull { it.toIntOrNull() }
            return if (parts.size == 2) CellPos(parts[0], parts[1]) else null
        }
    }
}
