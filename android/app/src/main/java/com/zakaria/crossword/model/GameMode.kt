package com.zakaria.crossword.model

/** The two ways to play. */
enum class GameMode(val title: String) {
    Crossword("كلمات متقاطعة"),
    WordSearch("كلمات مخفية"),
}

/** Word-search packs have ids like "ws-p01" (see WordSearchContent). */
val Pack.isWordSearch: Boolean get() = id.startsWith("ws-")
