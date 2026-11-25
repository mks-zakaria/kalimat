package com.zakaria.crossword.model

import kotlinx.serialization.Serializable

/**
 * What a level saves: only letters the player has earned (solved or revealed),
 * so a half-typed word is never "remembered" wrongly. Same fields as the iOS save file.
 * Every field has a default, so saves from older versions still load.
 */
@Serializable
data class LevelProgress(
    val filled: Map<String, String> = emptyMap(),        // "row,col" -> letter
    val solved: List<String> = emptyList(),              // entry ids
    val revealed: List<String> = emptyList(),            // cells (or word-search marks) given by a hint
    val removedDecoys: Map<String, Int> = emptyMap(),    // entry id -> decoys removed by a hint
    val hintsUsed: Int = 0,
    val stars: Int = 0,
    val completedAt: String? = null,                     // ISO-8601 time of the first completion
    val elapsed: Double = 0.0,                           // active solving seconds (kept by ProgressStore)
    val iq: Int? = null,                                 // this level's IQ score at its first completion
)
