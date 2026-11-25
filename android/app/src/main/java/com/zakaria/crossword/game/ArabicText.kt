package com.zakaria.crossword.game

/**
 * Must match `normalise()` in tools/generate.py and the iOS app exactly. Only tashkeel,
 * tatweel and spaces are removed: hamza forms and ى are kept, so words show their real spelling.
 */
object ArabicText {
    fun normalise(s: String): String = buildString {
        for (ch in s) {
            val code = ch.code
            val isTashkeel = code in 0x064B..0x0652 || code == 0x0670
            val isTatweel = code == 0x0640
            if (isTashkeel || isTatweel || ch == ' ') continue
            append(if (ch == 'ٱ') 'ا' else ch)
        }
    }

    /** Common letters used as decoys in the letter bank. */
    val decoys: List<String> = "ابتجحدرسعفقكلمنهوية".map { it.toString() }
}
