package com.zakaria.crossword.game

/**
 * Small deterministic random generator, seeded from a text.
 *
 * It is a line-by-line copy of the iOS app's `SeededRNG` (FNV-1a seed, xorshift64* steps), and
 * [nextInt], [pick] and [shuffle] repeat the exact algorithms of Swift's standard library.
 * So the same seed gives the same letter bank and the same word-search grid on Android and
 * iPhone: a player who switches phones sees the same puzzles.
 */
class SeededRng(seed: String) {
    private var state: ULong

    init {
        var h = 0xcbf29ce484222325uL                       // FNV-1a over the UTF-8 bytes
        for (b in seed.encodeToByteArray()) {
            h = h xor b.toUByte().toULong()
            h *= 0x100000001b3uL
        }
        state = if (h == 0uL) 0x9E3779B97F4A7C15uL else h
    }

    /** Next raw 64-bit value (xorshift64*). */
    fun next(): ULong {
        state = state xor (state shr 12)
        state = state xor (state shl 25)
        state = state xor (state shr 27)
        return state * 2685821657736338717uL
    }

    /** A number in 0 until [bound], like Swift's `next(upperBound:)` (Lemire's method). */
    private fun nextBelow(bound: ULong): ULong {
        var random = next()
        var low = random * bound
        if (low < bound) {
            val threshold = (0uL - bound) % bound
            while (low < threshold) {
                random = next()
                low = random * bound
            }
        }
        return multiplyHigh(random, bound)
    }

    /** Like Swift's `Int.random(in: 0..<until, using:)`. */
    fun nextInt(until: Int): Int = nextBelow(until.toULong()).toInt()

    /** Like Swift's `Int.random(in: range, using:)` for a closed range. */
    fun nextInt(range: IntRange): Int = range.first + nextBelow((range.last - range.first + 1).toULong()).toInt()

    /** Like Swift's `randomElement(using:)`. */
    fun <T> pick(list: List<T>): T = list[nextInt(list.size)]

    /** Like Swift's `shuffle(using:)`: walks forward, swapping each item with a later one. */
    fun <T> shuffle(list: MutableList<T>) {
        var remaining = list.size
        var i = 0
        while (remaining > 1) {
            val j = i + nextInt(remaining)
            remaining -= 1
            val tmp = list[i]; list[i] = list[j]; list[j] = tmp
            i += 1
        }
    }

    private companion object {
        /** High 64 bits of the 128-bit product a × b. */
        fun multiplyHigh(a: ULong, b: ULong): ULong {
            val mask = 0xFFFFFFFFuL
            val aLo = a and mask; val aHi = a shr 32
            val bLo = b and mask; val bHi = b shr 32
            val loLo = aLo * bLo
            val hiLo = aHi * bLo
            val loHi = aLo * bHi
            val cross = (loLo shr 32) + (hiLo and mask) + loHi
            return (hiLo shr 32) + (cross shr 32) + aHi * bHi
        }
    }
}
