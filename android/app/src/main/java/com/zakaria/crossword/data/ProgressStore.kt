package com.zakaria.crossword.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.zakaria.crossword.game.IQ
import com.zakaria.crossword.game.IQResult
import com.zakaria.crossword.model.Level
import com.zakaria.crossword.model.LevelProgress
import com.zakaria.crossword.model.Pack
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant

@Serializable
data class Settings(val sound: Boolean = true)

/** The whole save file. Same fields as the iOS one; every field has a default. */
@Serializable
data class SaveFile(
    val version: Int = 1,
    val updatedAt: String = Instant.now().toString(),
    val currentLevelId: String? = null,
    val levels: Map<String, LevelProgress> = emptyMap(),
    val coins: Int = ProgressStore.STARTING_COINS,
    val settings: Settings = Settings(),
    val iq: Double? = null,                    // overall IQ score (see game/IQ.kt)
    val iqLevels: Int = 0,                     // first completions it is based on
    val reviewAskedVersion: String? = null,    // app version the rating prompt was last shown for
)

/**
 * Everything the player has earned, in one small JSON file in the app's private storage.
 * [file] is Compose state: every screen that reads it redraws when it changes.
 */
class ProgressStore(private val path: File, private val appVersion: String) {

    var file by mutableStateOf(load()); private set

    private fun load(): SaveFile = try {
        json.decodeFromString(SaveFile.serializer(), path.readText())
    } catch (_: Exception) {
        SaveFile()                              // first launch, or an unreadable file
    }

    /** Changes the save file and writes it to disk straight away. */
    private fun change(edit: (SaveFile) -> SaveFile) {
        file = edit(file).copy(updatedAt = Instant.now().toString())
        persist()
    }

    // ---- levels ----

    fun progress(levelId: String): LevelProgress? = file.levels[levelId]
    fun stars(levelId: String): Int = file.levels[levelId]?.stars ?: 0
    fun isComplete(levelId: String): Boolean = file.levels[levelId]?.completedAt != null

    fun update(levelId: String, p: LevelProgress) {
        val old = file.levels[levelId]
        // keep the first completion date, the best stars, and what only the store tracks
        val merged = if (old == null) p else p.copy(
            completedAt = old.completedAt ?: p.completedAt,
            stars = maxOf(old.stars, p.stars),
            elapsed = old.elapsed,
            iq = old.iq,
        )
        change { it.copy(levels = it.levels + (levelId to merged), currentLevelId = levelId) }
    }

    /** Levels open one after another inside a pack. */
    fun isUnlocked(level: Level, pack: Pack): Boolean {
        val i = pack.levels.indexOf(level)
        return i == 0 || (i > 0 && isComplete(pack.levels[i - 1].id))
    }

    /** A pack opens when the one before it is complete. */
    fun isUnlocked(pack: Pack, packs: List<Pack>): Boolean {
        val i = packs.indexOf(pack)
        return i == 0 || (i > 0 && packs[i - 1].levels.all { isComplete(it.id) })
    }

    fun solvedCount(pack: Pack): Int = pack.levels.count { isComplete(it.id) }
    fun totalStars(pack: Pack): Int = pack.levels.sumOf { stars(it.id) }
    val finishedLevels: Int get() = file.levels.values.count { it.completedAt != null }

    /** First unfinished, unlocked level across all packs. */
    fun nextLevel(packs: List<Pack>): Pair<Level, Pack>? {
        for (pack in packs) {
            if (!isUnlocked(pack, packs)) continue
            val level = pack.levels.firstOrNull { !isComplete(it.id) && isUnlocked(it, pack) }
            if (level != null) return level to pack
        }
        return null
    }

    // ---- IQ ----

    val iq: Int? get() = file.iq?.let { Math.round(it).toInt() }
    val bestLevelIQ: Int? get() = file.levels.values.mapNotNull { it.iq }.maxOrNull()

    /** Score of the most recently finished level that counted. */
    val lastLevelIQ: Int?
        get() = file.levels.values.filter { it.iq != null }.maxByOrNull { it.completedAt ?: "" }?.iq

    /** Adds active solving time to a level that is not scored yet. */
    fun addTime(levelId: String, seconds: Double) {
        if (seconds <= 0 || seconds >= 6 * 3600) return          // ignore clock jumps
        val p = file.levels[levelId] ?: LevelProgress()
        if (p.iq != null) return
        change { it.copy(levels = it.levels + (levelId to p.copy(elapsed = p.elapsed + seconds))) }
    }

    /** Scores a finished level and updates the overall IQ — first completion only. */
    fun recordIQ(levelId: String, expected: Double, hints: Int): IQResult {
        val before = iq
        val p = file.levels[levelId]
        if (p == null || p.iq != null) {
            return IQResult(level = p?.iq ?: 100, before = before, after = before ?: 100, counted = false)
        }
        val score = IQ.levelScore(expected, p.elapsed, hints)
        change {
            it.copy(
                levels = it.levels + (levelId to p.copy(iq = score)),
                iq = IQ.updated(it.iq, it.iqLevels, score),
                iqLevels = it.iqLevels + 1,
            )
        }
        return IQResult(level = score, before = before, after = iq ?: score, counted = true)
    }

    // ---- rating prompt ----

    /**
     * Ask for a rating at most once per app version, only after real play: on the 8th,
     * 30th or 80th finished level. Google Play also limits how often the card really shows.
     */
    fun shouldAskForReview(): Boolean {
        if (finishedLevels !in listOf(8, 30, 80) || file.reviewAskedVersion == appVersion) return false
        change { it.copy(reviewAskedVersion = appVersion) }
        return true
    }

    // ---- settings ----

    var soundOn: Boolean
        get() = file.settings.sound
        set(value) = change { it.copy(settings = it.settings.copy(sound = value)) }

    // ---- coins ----

    val coins: Int get() = file.coins

    /** Takes [n] coins if the player has them. */
    fun spend(n: Int): Boolean {
        if (file.coins < n) return false
        change { it.copy(coins = it.coins - n) }
        return true
    }

    fun earn(n: Int) = change { it.copy(coins = it.coins + n) }

    // ---- disk ----

    /** Writes a temporary file, then renames it: a crash never leaves half a save. */
    private fun persist() {
        try {
            val tmp = File(path.parentFile, path.name + ".tmp")
            tmp.writeText(json.encodeToString(SaveFile.serializer(), file))
            if (!tmp.renameTo(path)) { path.delete(); tmp.renameTo(path) }
        } catch (_: Exception) {
            // the game keeps working from memory; the next change tries again
        }
    }

    companion object {
        const val STARTING_COINS = 100
        const val REVEAL_COST = 20
        const val REMOVE_COST = 10

        private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    }
}
