package com.zakaria.crossword

import com.zakaria.crossword.game.IQ
import org.junit.Assert.assertEquals
import org.junit.Test

class IQTest {
    @Test
    fun onPaceIsOneHundred() = assertEquals(100, IQ.levelScore(expected = 60.0, actual = 60.0, hints = 0))

    @Test
    fun twiceAsFastIsOneTwenty() = assertEquals(120, IQ.levelScore(expected = 60.0, actual = 30.0, hints = 0))

    @Test
    fun twiceAsSlowIsEighty() = assertEquals(80, IQ.levelScore(expected = 60.0, actual = 120.0, hints = 0))

    @Test
    fun eachHintCostsFive() = assertEquals(90, IQ.levelScore(expected = 60.0, actual = 60.0, hints = 2))

    @Test
    fun scoreStaysInRange() {
        assertEquals(160, IQ.levelScore(expected = 600.0, actual = 0.0, hints = 0))
        assertEquals(70, IQ.levelScore(expected = 10.0, actual = 9999.0, hints = 9))
    }

    @Test
    fun firstLevelSetsTheOverallScore() = assertEquals(112.0, IQ.updated(null, 0, 112), 0.0)

    @Test
    fun laterLevelsMoveItLess() {
        assertEquals(110.0, IQ.updated(100.0, 1, 120), 0.0)                   // weight 1/2
        assertEquals(103.0, IQ.updated(100.0, 50, 120), 0.0)                  // weight never below 0.15
    }
}
