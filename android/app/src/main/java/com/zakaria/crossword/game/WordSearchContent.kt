package com.zakaria.crossword.game

import com.zakaria.crossword.model.Entry
import com.zakaria.crossword.model.Level
import com.zakaria.crossword.model.Pack
import java.util.Locale

/**
 * Word-search packs are made from the crossword packs at launch: the same clues, regrouped
 * (shuffled, easy words first, about 7 per level), so a word-search level is never a copy of
 * a crossword level. Deterministic: the same groups on every launch, phone and platform.
 */
object WordSearchContent {
    const val PACK_PREFIX = "ws-"
    private const val WORDS_PER_LEVEL = 7

    fun packs(from: List<Pack>): List<Pack> = from.map { pack ->
        pack.copy(id = PACK_PREFIX + pack.id, levels = group(pack))
    }

    private fun group(pack: Pack): List<Level> {
        // shuffle with a seeded key, then put easy words first
        val rng = SeededRng("ws-pack:" + pack.id)
        val words = pack.levels.flatMap { it.entries }
            .map { it to rng.next() }
            .sortedWith(compareBy<Pair<Entry, ULong>> { it.first.difficulty }.thenBy { it.second })
            .map { it.first }

        val count = maxOf(1, Math.round(words.size.toDouble() / WORDS_PER_LEVEL).toInt())
        val groups: MutableList<MutableList<Entry>> = (0 until count)
            .map { i -> words.subList(words.size * i / count, words.size * (i + 1) / count).toMutableList() }
            .filter { it.isNotEmpty() }
            .toMutableList()

        // Never hand the player a crossword level again as a word search. Sorting by difficulty
        // can rebuild one (a crossword level made only of the hardest words), so trade one word
        // with the neighbouring group.
        val crosswordLevels = pack.levels.map { level -> level.entries.map { it.id }.toSet() }.toSet()
        for (i in groups.indices) {
            if (groups.size > 1 && groups[i].map { it.id }.toSet() in crosswordLevels) {
                val j = if (i > 0) i - 1 else i + 1
                val a = groups[i].removeAt(0)
                val b = groups[j].removeAt(groups[j].lastIndex)
                groups[i].add(0, b)
                groups[j].add(a)
            }
        }
        return groups.mapIndexed { i, g ->
            // Locale.ROOT: an Arabic phone would otherwise write the number in Arabic-Indic digits
            Level(id = String.format(Locale.ROOT, "%s-w%03d", pack.id, i + 1), number = i + 1, width = 0, height = 0, entries = g)
        }
    }
}
