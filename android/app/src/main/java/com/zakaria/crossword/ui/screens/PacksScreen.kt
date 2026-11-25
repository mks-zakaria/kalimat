package com.zakaria.crossword.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Star
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.LocalApp
import com.zakaria.crossword.model.GameMode
import com.zakaria.crossword.model.Pack
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds
import com.zakaria.crossword.ui.components.GameIcon
import com.zakaria.crossword.ui.components.ProgressBar
import com.zakaria.crossword.ui.components.SceneBackground
import com.zakaria.crossword.ui.components.SceneMood
import com.zakaria.crossword.ui.components.SceneTopBar
import com.zakaria.crossword.ui.components.Toast
import com.zakaria.crossword.ui.components.TopBarActions
import com.zakaria.crossword.ui.components.pressable
import com.zakaria.crossword.ui.components.rememberToast
import com.zakaria.crossword.ui.navigation.Navigator
import com.zakaria.crossword.ui.navigation.Route
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.NumberText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Radius
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.TextSize
import com.zakaria.crossword.ui.theme.arNum

/** S02 — the packs of one game mode, each with its own scene. */
@Composable
fun PacksScreen(nav: Navigator, startMode: GameMode) {
    val app = LocalApp.current
    val store = app.store
    var mode by remember { mutableStateOf(startMode) }
    val toast = rememberToast()
    val packs = if (mode == GameMode.Crossword) app.packs else app.wsPacks

    Box(Modifier.fillMaxSize()) {
        SceneBackground(SceneMood.Night, duneHeight = 0.2f)
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            SceneTopBar("المجموعات", onBack = nav::pop) { TopBarActions() }
            ModePicker(mode, onChange = { Sounds.play(Sound.Tap); mode = it }, modifier = Modifier.padding(horizontal = Space.lg).padding(top = Space.sm))
            LazyColumn(
                contentPadding = PaddingValues(Space.lg),
                verticalArrangement = Arrangement.spacedBy(Space.lg),
            ) {
                items(packs, key = { it.id }) { pack ->
                    val open = store.isUnlocked(pack, packs)
                    PackCard(
                        pack, solved = store.solvedCount(pack), stars = store.totalStars(pack), locked = !open,
                        modifier = Modifier.pressable {
                            if (open) nav.push(Route.Levels(pack))
                            else {
                                Sounds.play(Sound.Wrong)
                                toast.value = "أكمل المجموعة السابقة لفتح هذه المجموعة"
                            }
                        },
                    )
                }
            }
        }
        Toast(toast)
    }
}

/** Switch between the two ways to play. */
@Composable
private fun ModePicker(mode: GameMode, onChange: (GameMode) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .fillMaxWidth()
            .background(Palette.coinPill.copy(alpha = 0.6f), CircleShape)
            .border(1.dp, Color.White.copy(alpha = 0.3f), CircleShape)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        for (m in GameMode.entries) {
            val selected = m == mode
            Box(
                Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(CircleShape)
                    .background(if (selected) Palette.gold else Color.Transparent)
                    .clickable(remember { MutableInteractionSource() }, null, role = Role.Tab) { if (!selected) onChange(m) },
                contentAlignment = Alignment.Center,
            ) {
                ArabicText(m.title, 16.sp, if (selected) Palette.onGold else Color.White)
            }
        }
    }
}

/** A pack: its scene on top, then title and progress (or how to unlock it). */
@Composable
private fun PackCard(pack: Pack, solved: Int, stars: Int, locked: Boolean, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(Radius.card)
    Column(
        modifier
            .fillMaxWidth()
            .shadow(10.dp, shape)
            .clip(shape)
            .border(2.dp, Palette.gold, shape),
    ) {
        Box(Modifier.fillMaxWidth().height(110.dp), contentAlignment = Alignment.Center) {
            SceneBackground(SceneMood.forPack(pack.order), duneHeight = 0.45f, animated = false)
            if (locked) {
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)))
                GameIcon(Icons.Filled.Lock, Color.White, size = 30.dp)
            }
        }
        Row(
            Modifier
                .fillMaxWidth()
                .background(Palette.panel)
                .padding(Space.lg),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Space.md),
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                ArabicText(pack.titleAr, TextSize.title, Palette.panelText)
                if (locked) {
                    ArabicText("أكمل المجموعة السابقة لفتحها", TextSize.caption, Palette.panelMuted)
                } else {
                    ProgressBar(if (pack.levels.isEmpty()) 0f else solved.toFloat() / pack.levels.size)
                }
            }
            if (!locked) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    NumberText("${arNum(solved)}/${arNum(pack.levels.size)}", TextSize.number, Palette.panelText)
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                        GameIcon(Icons.Filled.Star, Palette.goldShade, size = 12.dp)
                        NumberText(arNum(stars), 12.sp, Palette.panelMuted)
                    }
                }
            }
        }
    }
}
