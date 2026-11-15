package com.zakaria.crossword.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.zakaria.crossword.LocalApp
import com.zakaria.crossword.model.Pack
import com.zakaria.crossword.ui.components.GameIcon
import com.zakaria.crossword.ui.components.LevelMedallion
import com.zakaria.crossword.ui.components.MedallionState
import com.zakaria.crossword.ui.components.SceneBackground
import com.zakaria.crossword.ui.components.SceneMood
import com.zakaria.crossword.ui.components.SceneTopBar
import com.zakaria.crossword.ui.components.Toast
import com.zakaria.crossword.ui.components.TopBarActions
import com.zakaria.crossword.ui.components.pressable
import com.zakaria.crossword.ui.components.rememberToast
import com.zakaria.crossword.ui.navigation.Navigator
import com.zakaria.crossword.ui.navigation.Route
import com.zakaria.crossword.ui.theme.NumberText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.TextSize
import com.zakaria.crossword.ui.theme.arNum

/** S03 — the levels of one pack, as medallions on a winding path. */
@Composable
fun LevelsScreen(nav: Navigator, pack: Pack) {
    val store = LocalApp.current.store
    val toast = rememberToast()
    val nextId = pack.levels.firstOrNull { !store.isComplete(it.id) && store.isUnlocked(it, pack) }?.id

    Box(Modifier.fillMaxSize()) {
        SceneBackground(SceneMood.forPack(pack.order), duneHeight = 0.25f)
        Column(Modifier.fillMaxSize().safeDrawingPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            SceneTopBar(pack.titleAr, onBack = nav::pop) { TopBarActions() }

            Row(
                Modifier
                    .padding(top = Space.sm)
                    .background(Palette.coinPill.copy(alpha = 0.55f), CircleShape)
                    .padding(horizontal = Space.md, vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                GameIcon(Icons.Filled.Star, Palette.gold, size = 18.dp)
                NumberText("${arNum(store.totalStars(pack))} / ${arNum(pack.levels.size * 3)}", TextSize.number, Color.White)
            }

            LazyColumn(
                Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(vertical = Space.xl),
                verticalArrangement = Arrangement.spacedBy(Space.md),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                itemsIndexed(pack.levels, key = { _, level -> level.id }) { i, level ->
                    val unlocked = store.isUnlocked(level, pack)
                    val state = when {
                        store.isComplete(level.id) -> MedallionState.Solved(store.stars(level.id))
                        unlocked -> MedallionState.Open
                        else -> MedallionState.Locked
                    }
                    LevelMedallion(
                        level.number, state, isNext = level.id == nextId,
                        modifier = Modifier
                            .offset(x = listOf(0, 70, 0, -70)[i % 4].dp)           // winding path
                            .semantics { contentDescription = "لغز ${arNum(level.number)}" }
                            .pressable {
                                if (unlocked) nav.push(Route.Board(level, pack))
                                else toast.value = "أكمل اللغز السابق أولًا"
                            },
                    )
                }
            }
        }
        Toast(toast)
    }
}
