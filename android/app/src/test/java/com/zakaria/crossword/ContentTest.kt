package com.zakaria.crossword

import com.zakaria.crossword.model.CellPos
import com.zakaria.crossword.model.Direction
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ContentTest {
    @Test
    fun allPacksLoadInOrder() {
        val packs = TestPacks.all
        assertEquals(8, packs.size)
        assertEquals((1..8).toList(), packs.map { it.order })
        assertTrue(packs.all { it.levels.isNotEmpty() })
    }

    @Test
    fun everyWordFitsOnItsBoard() {
        for (level in TestPacks.all.flatMap { it.levels }) {
            for (e in level.entries) {
                for (c in e.cells) {
                    assertTrue("${level.id} ${e.id}", c.row in 0 until level.height && c.col in 0 until level.width)
                }
            }
        }
    }

    @Test
    fun cellsFollowTheDirection() {
        val e = TestPacks.all[0].levels[0].entries.first { it.dir == Direction.Down }
        assertEquals(CellPos(e.row + 1, e.col), e.cells[1])
    }

    @Test
    fun cellKeyRoundTrips() {
        assertEquals(CellPos(3, 7), CellPos.fromKey(CellPos(3, 7).key))
    }
}
