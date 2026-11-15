package com.zakaria.crossword

import com.zakaria.crossword.game.WordSearchContent
import com.zakaria.crossword.game.WordSearchEngine
import com.zakaria.crossword.game.WordSearchGenerator
import com.zakaria.crossword.model.CellPos
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WordSearchTest {
    private val wsPacks = WordSearchContent.packs(TestPacks.all)

    /**
     * wordsearch-ios.json was exported by the iOS app's own code (app/tools/export_wordsearch.swift).
     * Every level, grid letter and hidden word must be identical on Android.
     */
    @Test
    fun everyLevelMatchesTheIosApp() {
        val text = javaClass.classLoader!!.getResource("wordsearch-ios.json")!!.readText()
        val ios = Json.parseToJsonElement(text).jsonArray
        assertEquals(ios.size, wsPacks.size)

        for ((pack, iosPack) in wsPacks.zip(ios)) {
            val iosLevels = iosPack.jsonObject["levels"]!!.jsonArray
            assertEquals(pack.id, iosPack.jsonObject["id"]!!.jsonPrimitive.content)
            assertEquals(pack.id, iosLevels.size, pack.levels.size)

            for ((level, iosLevel) in pack.levels.zip(iosLevels)) {
                val o = iosLevel.jsonObject
                assertEquals(o["id"]!!.jsonPrimitive.content, level.id)
                val puzzle = WordSearchGenerator.make(level)
                assertEquals(level.id, o["size"]!!.jsonPrimitive.int, puzzle.size)
                val grid = o["grid"]!!.jsonArray.map { row -> row.jsonArray.map { it.jsonPrimitive.content } }
                assertEquals(level.id, grid, puzzle.grid)
                for (e in o["entries"]!!.jsonArray.map { it.jsonObject }) {
                    val id = e["id"]!!.jsonPrimitive.content
                    val cells = e["cells"]!!.jsonArray.map { CellPos(it.jsonArray[0].jsonPrimitive.int, it.jsonArray[1].jsonPrimitive.int) }
                    assertEquals("${level.id} $id", cells, puzzle.placements[id]!!.cells)
                }
            }
        }
    }

    @Test
    fun everyAnswerIsReallyInTheGrid() {
        for (level in wsPacks.flatMap { it.levels }) {
            val p = WordSearchGenerator.make(level)
            for (e in level.entries) {
                val spelled = p.placements[e.id]!!.cells.map { p.letter(it) }
                assertEquals(WordSearchGenerator.letters(e), spelled)
            }
        }
    }

    @Test
    fun drawingAWordFindsItInBothDirections() {
        val level = wsPacks[0].levels[0]
        val g = WordSearchEngine(level)
        val e = level.entries[0]
        val cells = g.puzzle.placements[e.id]!!.cells
        assertEquals(WordSearchEngine.Result.Found(e), g.select(cells.reversed()))
        assertTrue(g.isFound(e))
    }

    @Test
    fun oneCellIsTooShort() {
        val g = WordSearchEngine(wsPacks[0].levels[0])
        assertEquals(WordSearchEngine.Result.TooShort, g.select(listOf(CellPos(0, 0))))
    }

    @Test
    fun levelIdsUseLatinDigitsOnAnArabicPhone() {
        val before = java.util.Locale.getDefault()
        try {
            java.util.Locale.setDefault(java.util.Locale.forLanguageTag("ar-SA"))
            assertEquals("ws-p01", WordSearchContent.packs(TestPacks.all)[0].id)
            assertEquals("p01-w001", WordSearchContent.packs(TestPacks.all)[0].levels[0].id)
        } finally {
            java.util.Locale.setDefault(before)
        }
    }

    @Test
    fun lineAcceptsOnlyStraightLines() {
        assertEquals(listOf(CellPos(0, 0), CellPos(1, 1), CellPos(2, 2)), WordSearchEngine.line(CellPos(0, 0), CellPos(2, 2)))
        assertNull(WordSearchEngine.line(CellPos(0, 0), CellPos(1, 2)))
    }

    @Test
    fun hintsAreSavedAndRestored() {
        val level = wsPacks[0].levels[0]
        val g = WordSearchEngine(level)
        g.showWord(level.entries[0])
        g.showStart(level.entries[1])
        val restored = WordSearchEngine(level, g.snapshot())
        assertEquals(setOf(level.entries[0].id), restored.shownWords)
        assertEquals(setOf(level.entries[1].id), restored.shownStarts)
        assertEquals(2, restored.hintsUsed)
    }

    @Test
    fun noWordSearchLevelCopiesACrosswordLevel() {
        for ((cw, ws) in TestPacks.all.zip(wsPacks)) {
            val crossword = cw.levels.map { l -> l.entries.map { it.id }.toSet() }.toSet()
            assertTrue(ws.levels.none { l -> l.entries.map { it.id }.toSet() in crossword })
        }
    }
}
