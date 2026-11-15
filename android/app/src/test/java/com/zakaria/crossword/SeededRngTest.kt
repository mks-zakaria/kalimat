package com.zakaria.crossword

import com.zakaria.crossword.game.ArabicText
import com.zakaria.crossword.game.SeededRng
import org.junit.Assert.assertEquals
import org.junit.Test

/** Expected values were printed by the iOS code (Swift), so these prove both apps agree. */
class SeededRngTest {
    @Test
    fun rawValuesMatchSwift() {
        val rng = SeededRng("abc")
        assertEquals(17965033732531672793uL, rng.next())
        assertEquals(13978924921052248732uL, rng.next())
        assertEquals(11023063779569587599uL, rng.next())
    }

    @Test
    fun intsInRangeMatchSwift() {
        val rng = SeededRng("p01-001gen039")
        assertEquals(listOf(1, 1, 1, 0, 3, 2, 2, 2), List(8) { rng.nextInt(0..4) })
    }

    @Test
    fun shuffleMatchesSwift() {
        val list = (0 until 12).toMutableList()
        SeededRng("shuffle").shuffle(list)
        assertEquals(listOf(7, 4, 10, 9, 1, 6, 2, 0, 5, 8, 11, 3), list)
    }

    @Test
    fun pickMatchesSwift() {
        val rng = SeededRng("dp01-001gen039")
        assertEquals("يكةدرم", List(6) { rng.pick(ArabicText.decoys) }.joinToString(""))
    }

    @Test
    fun normaliseRemovesTashkeelTatweelAndSpaces() {
        assertEquals("الكتابال", ArabicText.normalise("ٱلْكِتَابُ ـالـ"))
    }
}
