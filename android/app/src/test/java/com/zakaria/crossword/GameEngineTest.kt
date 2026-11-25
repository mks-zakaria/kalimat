package com.zakaria.crossword

import com.zakaria.crossword.game.GameEngine
import com.zakaria.crossword.model.LevelProgress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GameEngineTest {
    private val level = TestPacks.all[0].levels[0]

    private fun bankText(g: GameEngine) = g.bank.joinToString(" ") { it.letter + if (it.isDecoy) "*" else "" }

    /** Typing every letter of [answer] from the bank, in order. */
    private fun type(g: GameEngine, answer: String) {
        for (ch in answer) g.tapKey(g.bank.first { it.letter == ch.toString() && !it.used && !it.removed })
    }

    @Test
    fun letterBankMatchesTheIosApp() {
        val g = GameEngine(level)
        g.open(level.entries[0])
        assertEquals("ع ق ي* ل م* ة* د* ر* م* م ك* ة", bankText(g))   // printed by the Swift engine
        g.revealLetter()
        assertEquals("ق ة ك* ع م* د* ر* م* ي* ل ة* ي*", bankText(g))
    }

    @Test
    fun rightAnswerSolvesTheWord() {
        val g = GameEngine(level)
        val e = level.entries[0]
        g.open(e)
        type(g, e.answer)
        assertTrue(e.id in g.solved)
        assertFalse(g.lastWrong)
    }

    @Test
    fun wrongAnswerClearsTheSlots() {
        val g = GameEngine(level)
        val e = level.entries[0]
        g.open(e)
        val decoy = g.bank.first { it.isDecoy }
        g.tapKey(decoy)
        type(g, e.answer.drop(1))
        assertTrue(g.lastWrong)
        assertTrue(g.typed.all { it == null })
        assertTrue(g.bank.none { it.used })
    }

    @Test
    fun tappingASlotGivesTheKeyBack() {
        val g = GameEngine(level)
        g.open(level.entries[0])
        val key = g.bank[0]
        g.tapKey(key)
        g.tapSlot(0)
        assertNull(g.typed[0])
        assertFalse(g.bank[0].used)
    }

    @Test
    fun solvingEveryWordGivesThreeStars() {
        val g = GameEngine(level)
        var e = g.nextUnsolved(null)
        while (e != null) {
            g.open(e)
            val open = e
            // letters already on the board (from crossing words) are locked: type only the rest
            type(g, open.letters.filterIndexed { i, _ -> !g.isLocked(i) }.joinToString(""))
            e = g.nextUnsolved(e)
        }
        assertTrue(g.isComplete)
        assertEquals(3, g.stars)
    }

    @Test
    fun hintsLowerTheStars() {
        assertEquals(2, GameEngine.starsFor(true, 2))
        assertEquals(1, GameEngine.starsFor(true, 3))
        assertEquals(0, GameEngine.starsFor(false, 0))
    }

    @Test
    fun removeDecoyHidesOneWrongKey() {
        val g = GameEngine(level)
        g.open(level.entries[0])
        g.removeDecoy()
        assertEquals(1, g.bank.count { it.removed })
        assertTrue(g.bank.first { it.removed }.isDecoy)
        assertEquals(1, g.hintsUsed)
    }

    @Test
    fun progressIsSavedAndRestored() {
        var saved: LevelProgress? = null
        val g = GameEngine(level).apply { onProgress = { saved = it } }
        val e = level.entries[0]
        g.open(e)
        type(g, e.answer)
        g.open(level.entries[1])
        g.revealLetter()

        val restored = GameEngine(level, saved)
        assertEquals(g.solved, restored.solved)
        assertEquals(g.filled, restored.filled)
        assertEquals(g.revealed, restored.revealed)
        assertEquals(1, restored.hintsUsed)
    }
}
