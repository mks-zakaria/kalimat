package com.zakaria.crossword.data

import android.content.res.AssetManager
import com.zakaria.crossword.model.Pack
import kotlinx.serialization.json.Json

/** Loads every pack bundled in the app's assets (p01.json, p02.json, …). */
object ContentStore {
    private val json = Json { ignoreUnknownKeys = true }
    private val packFile = Regex("""p\d+\.json""")

    fun loadPacks(assets: AssetManager): List<Pack> =
        assets.list("").orEmpty()
            .filter { packFile.matches(it) }
            .map { name -> assets.open(name).bufferedReader().use { parse(it.readText()) } }
            .sortedBy { it.order }

    /** One pack from its JSON text (also used by the unit tests). */
    fun parse(text: String): Pack = json.decodeFromString(Pack.serializer(), text)
}
