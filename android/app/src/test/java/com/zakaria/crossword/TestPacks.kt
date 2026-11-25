package com.zakaria.crossword

import com.zakaria.crossword.data.ContentStore
import com.zakaria.crossword.model.Pack
import java.io.File

/** The real packs, read from the app's assets (unit tests run from the app/ folder). */
object TestPacks {
    val all: List<Pack> by lazy {
        File("src/main/assets").listFiles { f -> f.name.matches(Regex("""p\d+\.json""")) }!!
            .map { ContentStore.parse(it.readText()) }
            .sortedBy { it.order }
    }
}
