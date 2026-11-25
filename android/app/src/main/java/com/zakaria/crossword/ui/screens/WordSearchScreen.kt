package com.zakaria.crossword.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CenterFocusStrong
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.LocalApp
import com.zakaria.crossword.data.ProgressStore
import com.zakaria.crossword.game.IQ
import com.zakaria.crossword.game.WordSearchEngine
import com.zakaria.crossword.game.WordSearchGenerator
import com.zakaria.crossword.model.CellPos
import com.zakaria.crossword.model.Entry
import com.zakaria.crossword.model.GameMode
import com.zakaria.crossword.model.Level
import com.zakaria.crossword.model.Pack
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds
import com.zakaria.crossword.ui.coins.NoCoinsCard
import com.zakaria.crossword.ui.components.Category
import com.zakaria.crossword.ui.components.Dock
import com.zakaria.crossword.ui.components.GameIcon
import com.zakaria.crossword.ui.components.HintButton
import com.zakaria.crossword.ui.components.LetterGrid
import com.zakaria.crossword.ui.components.RevealHintButton
import com.zakaria.crossword.ui.components.SceneBackground
import com.zakaria.crossword.ui.components.SceneMood
import com.zakaria.crossword.ui.components.SceneTopBar
import com.zakaria.crossword.ui.components.TopBarActions
import com.zakaria.crossword.ui.components.pressable
import com.zakaria.crossword.ui.components.rememberShake
import com.zakaria.crossword.ui.iq.IQResultBox
import com.zakaria.crossword.ui.iq.SolveTiming
import com.zakaria.crossword.ui.navigation.Navigator
import com.zakaria.crossword.ui.navigation.Route
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Radius
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.TextSize
import com.zakaria.crossword.ui.theme.arNum
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * S08 — word search: the square of letters on top, the clues below. The player draws a
 * straight line (across, down or diagonal) over an answer, or taps its first letter then its last.
 */
@Composable
fun WordSearchScreen(nav: Navigator, level: Level, pack: Pack) {
    val store = LocalApp.current.store
    val scope = rememberCoroutineScope()
    val shake = rememberShake()
    var noCoins by remember { mutableStateOf(false) }

    val engine = remember {
        WordSearchEngine(level, store.progress(level.id)).apply { onProgress = { store.update(level.id, it) } }
    }
    val finish = rememberLevelFinish(level.id)
    var selectedId by remember { mutableStateOf<String?>(null) }    // the clue the hints apply to
    var lastFound by remember { mutableStateOf<String?>(null) }     // pulses its clue for a moment

    LaunchedEffect(Unit) { if (engine.isComplete) finish.showComplete = true }

    // hints apply to the chosen clue, or to the first word not found yet
    val target: Entry? = level.entries.firstOrNull { it.id == selectedId && !engine.isFound(it) } ?: engine.firstUnfound

    fun select(cells: List<CellPos>) {
        when (val result = engine.select(cells)) {
            is WordSearchEngine.Result.Found -> {
                Sounds.play(Sound.Correct)
                lastFound = result.entry.id
                scope.launch { delay(400); lastFound = null }
                if (selectedId == result.entry.id) selectedId = null
                if (engine.isComplete) {
                    finish.finish(engine.stars, engine.hintsUsed, IQ.expectedSeconds(level, GameMode.WordSearch, engine.puzzle.size))
                }
            }
            WordSearchEngine.Result.Wrong -> {
                Sounds.play(Sound.Wrong)
                scope.launch { shake.start() }
            }
            WordSearchEngine.Result.TooShort -> Unit
        }
    }

    fun useHint(cost: Int, action: () -> Unit) {
        if (!store.spend(cost)) {
            Sounds.play(Sound.Wrong)
            noCoins = true
            return
        }
        Sounds.play(Sound.Coin)
        Sounds.play(Sound.Hint)
        action()
    }

    SolveTiming(level.id, running = !engine.isComplete)

    Box(Modifier.fillMaxSize()) {
        SceneBackground(SceneMood.forPack(pack.order), duneHeight = 0.22f)

        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(Space.md)) {
            Box(Modifier.statusBarsPadding()) {
                SceneTopBar("${GameMode.WordSearch.title} · ${arNum(level.number)}", onBack = nav::pop) { TopBarActions() }
            }

            BoxWithConstraints(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = Space.lg),
                contentAlignment = Alignment.Center,
            ) {
                val starts = level.entries
                    .filter { it.id in engine.shownStarts && !engine.isFound(it) }
                    .mapNotNull { engine.startCell(it) }
                    .toSet()
                LetterGrid(
                    engine.puzzle, engine.found, starts, side = minOf(maxWidth, maxHeight),
                    onSelect = ::select, modifier = shake.modifier,
                )
            }

            Dock {
                Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                    val canWord = target?.let { engine.canShowWord(it) } ?: false
                    val canStart = target?.let { engine.canShowStart(it) } ?: false
                    RevealHintButton(ProgressStore.REVEAL_COST, canWord, title = "كشف الكلمة", onClick = {
                        useHint(ProgressStore.REVEAL_COST) { target?.let { engine.showWord(it) } }
                    })
                    HintButton("أول حرف", Icons.Filled.CenterFocusStrong, Palette.button, ProgressStore.REMOVE_COST, canStart, onClick = {
                        useHint(ProgressStore.REMOVE_COST) { target?.let { engine.showStart(it) } }
                    })
                }
                LazyColumn(
                    Modifier.heightIn(max = 260.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    itemsIndexed(level.entries, key = { _, e -> e.id }) { _, e ->
                        ClueRow(
                            e, done = engine.isFound(e), isTarget = target?.id == e.id,
                            showAnswer = engine.isFound(e) || e.id in engine.shownWords, pulse = lastFound == e.id,
                            onClick = {
                                Sounds.play(Sound.Tap)
                                selectedId = e.id
                            },
                        )
                    }
                }
            }
        }

        if (finish.showComplete) {
            LevelComplete(
                stars = engine.stars, reward = finish.reward, next = nextLevel(pack, level),
                onContinue = { next ->
                    if (next != null) nav.replaceTop(Route.Board(next, pack)) else nav.pop()
                    finish.leave(level.number)                   // between levels only
                },
            ) { finish.iq?.let { IQResultBox(it) } }
        }
    }
    if (noCoins) NoCoinsCard(onClose = { noCoins = false })
}

/** One clue in the list. Tap it to aim the hints at it; found words are struck through. */
@Composable
private fun ClueRow(e: Entry, done: Boolean, isTarget: Boolean, showAnswer: Boolean, pulse: Boolean, onClick: () -> Unit) {
    val cat = Category.of(e.category)
    val scale by animateFloatAsState(if (pulse) 1.04f else 1f, label = "found")
    val shape = RoundedCornerShape(Radius.key)
    Row(
        Modifier
            .fillMaxWidth()
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .background(if (isTarget) Palette.gold.copy(alpha = 0.28f) else Palette.tile, shape)
            .border(if (isTarget) 2.dp else 1.dp, if (isTarget) Palette.goldEdge else Palette.tileEdge.copy(alpha = 0.35f), shape)
            .pressable(enabled = !done, onClick = onClick)
            .padding(horizontal = Space.md, vertical = Space.sm),
        horizontalArrangement = Arrangement.spacedBy(Space.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        GameIcon(if (done) Icons.Filled.CheckCircle else cat.icon, if (done) Palette.success else cat.color, size = 20.dp)
        Column(Modifier.weight(1f)) {
            ArabicText(e.clueAr, 16.sp, if (done) Palette.panelMuted else Palette.panelText, strike = done)
            if (showAnswer) ArabicText(e.answer, 15.sp, if (done) Palette.success else Palette.turquoise)
        }
        ArabicText(lettersLabel(WordSearchGenerator.letters(e).size), TextSize.caption, Palette.panelMuted, maxLines = 1)
    }
}

/** Arabic number agreement: حرفان، ٣–١٠ حروف، ١١+ حرفًا. */
private fun lettersLabel(n: Int): String = when (n) {
    2 -> "حرفان"
    in 3..10 -> "${arNum(n)} حروف"
    else -> "${arNum(n)} حرفًا"
}
