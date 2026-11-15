package com.zakaria.crossword

import com.zakaria.crossword.data.ProgressStore
import com.zakaria.crossword.game.IQResult
import com.zakaria.crossword.model.LevelProgress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class ProgressStoreTest {
    @get:Rule val tmp = TemporaryFolder()

    private fun store(file: File = File(tmp.root, "progress.json")) = ProgressStore(file, "1.0.0")
    private val pack = TestPacks.all[0]
    private val done = LevelProgress(stars = 3, completedAt = "2026-11-15T10:00:00Z")

    @Test
    fun newPlayerStartsWithOneHundredCoins() = assertEquals(100, store().coins)

    @Test
    fun spendingNeedsEnoughCoins() {
        val s = store()
        assertTrue(s.spend(80))
        assertFalse(s.spend(30))
        assertEquals(20, s.coins)
    }

    @Test
    fun everythingSurvivesARestart() {
        val file = File(tmp.root, "progress.json")
        store(file).apply {
            earn(5)
            soundOn = false
            update(pack.levels[0].id, done)
        }
        val again = store(file)
        assertEquals(105, again.coins)
        assertFalse(again.soundOn)
        assertTrue(again.isComplete(pack.levels[0].id))
    }

    @Test
    fun anUnreadableFileStartsFresh() {
        val file = File(tmp.root, "progress.json").apply { writeText("not json") }
        assertEquals(100, store(file).coins)
    }

    @Test
    fun levelsUnlockOneByOne() {
        val s = store()
        assertTrue(s.isUnlocked(pack.levels[0], pack))
        assertFalse(s.isUnlocked(pack.levels[1], pack))
        s.update(pack.levels[0].id, done)
        assertTrue(s.isUnlocked(pack.levels[1], pack))
        assertEquals(pack.levels[1], s.nextLevel(TestPacks.all)?.first)
    }

    @Test
    fun replaysKeepTheBestStarsAndFirstDate() {
        val s = store()
        val id = pack.levels[0].id
        s.update(id, done)
        s.update(id, LevelProgress(stars = 1, completedAt = "2026-12-01T10:00:00Z"))
        assertEquals(3, s.stars(id))
        assertEquals("2026-11-15T10:00:00Z", s.progress(id)?.completedAt)
    }

    @Test
    fun iqCountsOnlyTheFirstCompletion() {
        val s = store()
        val id = pack.levels[0].id
        s.addTime(id, 30.0)
        s.update(id, done)
        val first = s.recordIQ(id, expected = 60.0, hints = 0)
        assertEquals(IQResult(level = 120, before = null, after = 120, counted = true), first)
        val replay = s.recordIQ(id, expected = 60.0, hints = 0)
        assertFalse(replay.counted)
        assertEquals(1, s.file.iqLevels)
    }

    @Test
    fun reviewIsAskedOnTheEighthLevelOnce() {
        val s = store()
        repeat(7) { s.update("x$it", done) }
        assertFalse(s.shouldAskForReview())
        s.update("x7", done)
        assertTrue(s.shouldAskForReview())
        assertFalse(s.shouldAskForReview())
    }

    @Test
    fun noIqBeforeTheFirstLevel() = assertNull(store().iq)
}
