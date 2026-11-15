package com.zakaria.crossword

import com.zakaria.crossword.data.ContentStore
import com.zakaria.crossword.model.Pack
import java.io.File

/** The real packs, read from the iOS resources folder (unit tests run from android/app). */
object TestPacks {
    val all: List<Pack> by lazy {
        File("../../app/Resources/Packs").listFiles { f -> f.name.endsWith(".json") }!!
            .map { ContentStore.parse(it.readText()) }
            .sortedBy { it.order }
    }
}
