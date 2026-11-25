package com.zakaria.crossword.game

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.zakaria.crossword.model.CellPos
import com.zakaria.crossword.model.Entry
import com.zakaria.crossword.model.Level
import com.zakaria.crossword.model.LevelProgress
import java.time.Instant

/** One letter key in the bank. `id` keeps duplicates (two "ا") apart. */
data class BankKey(
    val id: Int,
    val letter: String,
    val isDecoy: Boolean,
    val used: Boolean = false,
    val removed: Boolean = false,
)

/**
 * Rules for one crossword level. No UI and no coins in here: callers check the wallet
 * first, then call [revealLetter] / [removeDecoy].
 *
 * Every property the screen shows is Compose state, so the screen redraws by itself.
 */
class GameEngine(val level: Level, saved: LevelProgress? = null) {

    // Board
    var filled by mutableStateOf(mapOf<CellPos, String>()); private set
    var solved by mutableStateOf(setOf<String>()); private set
    var revealed by mutableStateOf(setOf<CellPos>()); private set
    var hintsUsed by mutableStateOf(0); private set
    private var removedDecoys = mapOf<String, Int>()

    // The open word
    var current by mutableStateOf<Entry?>(null); private set
    var typed by mutableStateOf(listOf<String?>()); private set
    private var typedFrom = listOf<Int?>()                  // which key filled each slot
    var bank by mutableStateOf(listOf<BankKey>()); private set
    var lastWrong by mutableStateOf(false); private set

    /** Called after every change worth saving. */
    var onProgress: ((LevelProgress) -> Unit)? = null

    init {
        if (saved != null) {
            filled = saved.filled.mapNotNull { (k, v) -> CellPos.fromKey(k)?.let { it to v } }.toMap()
            solved = saved.solved.toSet()
            revealed = saved.revealed.mapNotNull { CellPos.fromKey(it) }.toSet()
            hintsUsed = saved.hintsUsed
            removedDecoys = saved.removedDecoys
        }
    }

    // ---- board ----

    val allCells: Set<CellPos> get() = level.entries.flatMap { it.cells }.toSet()
    val isComplete: Boolean get() = solved.size == level.entries.size

    /** 3 stars with no hints, 2 with up to two, else 1. */
    val stars: Int get() = starsFor(isComplete, hintsUsed)

    fun entriesAt(cell: CellPos): List<Entry> = level.entries.filter { cell in it.cells }

    /** Tapping a crossing cell again switches to the other word. */
    fun entryToOpen(cell: CellPos, previous: Entry?): Entry? {
        val options = entriesAt(cell).filter { it.id !in solved }
        if (options.isEmpty()) return null
        val i = options.indexOf(previous)
        return if (i >= 0 && options.size > 1) options[(i + 1) % options.size] else options.first()
    }

    /** The next unsolved word after [entry] (wrapping round), for auto-advance. */
    fun nextUnsolved(entry: Entry?): Entry? {
        val list = level.entries
        val start = list.indexOf(entry)                     // -1 when entry is null
        for (k in 1..maxOf(list.size, 1)) {
            val e = list[(start + k + list.size) % list.size]
            if (e.id !in solved) return e
        }
        return null
    }

    // ---- open word ----

    fun open(entry: Entry) {
        current = entry
        lastWrong = false
        typed = entry.cells.map { filled[it] }
        typedFrom = List(entry.answer.length) { null }
        bank = makeBank(entry)
    }

    /** A slot is locked when its letter is already earned (solved crossing word or hint). */
    fun isLocked(index: Int): Boolean {
        val cell = current?.cells?.getOrNull(index) ?: return false
        return filled[cell] != null
    }

    fun isRevealed(index: Int): Boolean {
        val cell = current?.cells?.getOrNull(index) ?: return false
        return cell in revealed
    }

    val currentSolved: Boolean get() = current?.let { it.id in solved } ?: false

    fun tapKey(key: BankKey) {
        if (current == null || currentSolved) return
        val k = bank.indexOfFirst { it.id == key.id }
        if (k < 0 || bank[k].used || bank[k].removed) return
        val slot = typed.indexOfFirst { it == null }
        if (slot < 0) return

        lastWrong = false
        typed = typed.toMutableList().also { it[slot] = bank[k].letter }
        typedFrom = typedFrom.toMutableList().also { it[slot] = bank[k].id }
        bank = bank.toMutableList().also { it[k] = it[k].copy(used = true) }
        if (typed.none { it == null }) check()
    }

    /** Tapping a typed letter sends it back to the keys. */
    fun tapSlot(index: Int) {
        if (index !in typed.indices || isLocked(index)) return
        val keyId = typedFrom[index] ?: return
        typed = typed.toMutableList().also { it[index] = null }
        typedFrom = typedFrom.toMutableList().also { it[index] = null }
        bank = bank.map { if (it.id == keyId) it.copy(used = false) else it }
    }

    // ---- hints ----

    val canReveal: Boolean get() = current != null && !currentSolved
    val canRemoveDecoy: Boolean get() = !currentSolved && bank.any { it.isDecoy && !it.removed && !it.used }

    /** Puts the right letter in the first open slot (the right-most), locked, in hint colour. */
    fun revealLetter() {
        val e = current ?: return
        if (!canReveal) return
        val i = e.cells.indexOfFirst { filled[it] == null }
        if (i < 0) return

        clearTyped()
        filled = filled + (e.cells[i] to e.letters[i])
        revealed = revealed + e.cells[i]
        hintsUsed += 1
        val removed = removedDecoys[e.id] ?: 0
        open(e)                                             // rebuild the bank without that letter
        repeat(removed) { removeOneDecoy() }
        if (e.cells.all { filled[it] != null }) solve(e) else save()
    }

    /** Hides one letter that is not in the answer. */
    fun removeDecoy() {
        val e = current ?: return
        if (!canRemoveDecoy) return
        removeOneDecoy()
        removedDecoys = removedDecoys + (e.id to (removedDecoys[e.id] ?: 0) + 1)
        hintsUsed += 1
        save()
    }

    private fun removeOneDecoy() {
        val k = bank.indexOfFirst { it.isDecoy && !it.removed && !it.used }
        if (k >= 0) bank = bank.toMutableList().also { it[k] = it[k].copy(removed = true) }
    }

    private fun clearTyped() {
        for (i in typed.indices) if (!isLocked(i)) tapSlot(i)
    }

    // ---- checking ----

    private fun check() {
        val e = current ?: return
        if (typed.filterNotNull().joinToString("") == e.answer) {
            solve(e)
        } else {
            lastWrong = true
            clearTyped()
        }
    }

    private fun solve(e: Entry) {
        var newFilled = filled
        e.cells.forEachIndexed { i, c -> newFilled = newFilled + (c to e.letters[i]) }
        filled = newFilled
        typed = e.letters
        // a word whose every letter is now on the board (thanks to crossings) is solved too
        var newSolved = solved + e.id
        for (other in level.entries) {
            if (other.id !in newSolved && other.cells.all { filled[it] != null }) newSolved = newSolved + other.id
        }
        solved = newSolved
        save()
    }

    // ---- saving ----

    fun snapshot(): LevelProgress = LevelProgress(
        filled = filled.entries.associate { it.key.key to it.value },
        solved = solved.sorted(),
        revealed = revealed.map { it.key }.sorted(),
        removedDecoys = removedDecoys,
        hintsUsed = hintsUsed,
        stars = stars,
        completedAt = if (isComplete) Instant.now().toString() else null,
    )

    private fun save() {
        onProgress?.invoke(snapshot())
    }

    // ---- letter bank ----

    /** The answer's missing letters plus decoys, shuffled; always [BANK_SIZE] keys. */
    private fun makeBank(e: Entry): List<BankKey> {
        val rng = SeededRng(level.id + e.id)
        val keys = mutableListOf<Pair<String, Boolean>>()       // letter, isDecoy
        e.letters.forEachIndexed { i, letter -> if (filled[e.cells[i]] == null) keys += letter to false }
        // decoys come from their own fixed-seed stream, so they don't change after a reveal
        val decoyRng = SeededRng("d" + level.id + e.id)
        while (keys.size < BANK_SIZE) keys += decoyRng.pick(ArabicText.decoys) to true
        rng.shuffle(keys)
        return keys.mapIndexed { i, (letter, isDecoy) -> BankKey(i, letter, isDecoy) }
    }

    companion object {
        const val BANK_SIZE = 12

        /** Shared by both game modes. */
        fun starsFor(complete: Boolean, hints: Int): Int = when {
            !complete -> 0
            hints == 0 -> 3
            hints <= 2 -> 2
            else -> 1
        }
    }
}
