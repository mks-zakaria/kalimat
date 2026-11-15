package com.zakaria.crossword.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.zakaria.crossword.LocalApp
import com.zakaria.crossword.data.ProgressStore
import com.zakaria.crossword.game.BankKey
import com.zakaria.crossword.game.GameEngine
import com.zakaria.crossword.model.CellPos
import com.zakaria.crossword.model.Entry
import com.zakaria.crossword.model.Level
import com.zakaria.crossword.model.Pack
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds
import com.zakaria.crossword.ui.components.AnswerSlots
import com.zakaria.crossword.ui.components.CellState
import com.zakaria.crossword.ui.components.ClueCard
import com.zakaria.crossword.ui.components.CrosswordBoard
import com.zakaria.crossword.ui.components.Dock
import com.zakaria.crossword.ui.components.KeyState
import com.zakaria.crossword.ui.components.LetterKey
import com.zakaria.crossword.ui.components.RemoveHintButton
import com.zakaria.crossword.ui.components.RevealHintButton
import com.zakaria.crossword.ui.components.SceneBackground
import com.zakaria.crossword.ui.components.SceneMood
import com.zakaria.crossword.ui.components.SceneTopBar
import com.zakaria.crossword.ui.components.SlotState
import com.zakaria.crossword.ui.components.Toast
import com.zakaria.crossword.ui.components.TopBarActions
import com.zakaria.crossword.ui.components.rememberShake
import com.zakaria.crossword.ui.components.rememberToast
import com.zakaria.crossword.ui.navigation.Navigator
import com.zakaria.crossword.ui.navigation.Route
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.arNum
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * S04 + S05 on one screen: the crossword on top; the open word's clue, answer slots, hints
 * and letter keys below. Solving a word moves straight on to the next one.
 */
@Composable
fun BoardScreen(nav: Navigator, level: Level, pack: Pack) {
    val store = LocalApp.current.store
    val scope = rememberCoroutineScope()
    val shake = rememberShake()
    val toast = rememberToast()

    val engine = remember {
        GameEngine(level, store.progress(level.id)).apply { onProgress = { store.update(level.id, it) } }
    }
    val alreadyDone = remember { store.isComplete(level.id) }            // replays earn no coins
    var showComplete by remember { mutableStateOf(engine.isComplete) }
    var reward by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        if (!engine.isComplete) engine.nextUnsolved(null)?.let { engine.open(it) }
    }

    /** Coins, then stars and sounds, once the last word is solved. */
    fun finish() {
        reward = if (alreadyDone) 0 else if (engine.stars == 3) 10 else 5
        scope.launch {
            delay(500)
            if (reward > 0) store.earn(reward)
            showComplete = true
            delay(300)
            Sounds.play(Sound.Complete)
            repeat(engine.stars) {
                delay(380)
                Sounds.play(Sound.Star)
            }
        }
    }

    /** Reacts to what a key, slot or hint just did. */
    fun afterMove(solvedBefore: Int) {
        if (engine.lastWrong) {
            Sounds.play(Sound.Wrong)
            scope.launch { shake.start() }
        }
        if (engine.solved.size > solvedBefore) {
            Sounds.play(Sound.Correct)
            if (engine.isComplete) {
                finish()
            } else {
                scope.launch {
                    delay(450)                                     // let the player see the word turn gold
                    engine.nextUnsolved(engine.current)?.let { engine.open(it) }
                }
            }
        }
    }

    fun tapKey(key: BankKey) {
        Sounds.play(Sound.Key)
        val before = engine.solved.size
        engine.tapKey(key)
        afterMove(before)
    }

    fun useHint(cost: Int, sound: Sound, action: () -> Unit) {
        if (!store.spend(cost)) {
            Sounds.play(Sound.Wrong)
            toast.value = "رصيدك من العملات لا يكفي"
            return
        }
        Sounds.play(Sound.Coin)
        Sounds.play(sound)
        val before = engine.solved.size
        action()
        afterMove(before)
    }

    fun tapCell(cell: CellPos) {
        val e = engine.entryToOpen(cell, engine.current)
        if (e == null) {
            Sounds.play(Sound.Tap)
        } else {
            Sounds.play(Sound.Open)
            engine.open(e)
        }
    }

    Box(Modifier.fillMaxSize()) {
        SceneBackground(SceneMood.forPack(pack.order), duneHeight = 0.22f)

        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(Space.md)) {
            Box(Modifier.statusBarsPadding()) {
                SceneTopBar("لغز ${arNum(level.number)}", onBack = nav::pop) { TopBarActions() }
            }

            BoxWithConstraints(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = Space.lg),
                contentAlignment = Alignment.Center,
            ) {
                CrosswordBoard(
                    rows = level.height, cols = level.width,
                    letters = boardLetters(engine), states = cellStates(engine),
                    cellSize = cellSize(maxWidth, maxHeight, level),
                    cursor = cursorCell(engine),
                    onTap = ::tapCell,
                )
            }

            val entry = engine.current
            AnimatedVisibility(
                visible = entry != null && !engine.isComplete,
                enter = slideInVertically { it } + fadeIn(),
                exit = slideOutVertically { it } + fadeOut(),
            ) {
                if (entry != null) {
                    Dock {
                        ClueCard(entry.category, entry.clueAr)
                        AnswerSlots(
                            engine.typed, slotStates(engine),
                            onTap = { i ->
                                Sounds.play(Sound.Undo)
                                engine.tapSlot(i)
                            },
                            modifier = shake.modifier,
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
                            RevealHintButton(ProgressStore.REVEAL_COST, engine.canReveal, onClick = {
                                useHint(ProgressStore.REVEAL_COST, Sound.Hint) { engine.revealLetter() }
                            })
                            RemoveHintButton(ProgressStore.REMOVE_COST, engine.canRemoveDecoy, onClick = {
                                useHint(ProgressStore.REMOVE_COST, Sound.Erase) { engine.removeDecoy() }
                            })
                        }
                        LetterKeys(engine, ::tapKey)
                    }
                }
            }
        }

        if (showComplete) {
            LevelComplete(
                stars = engine.stars, reward = reward, next = nextLevel(pack, level),
                onContinue = { next -> if (next != null) nav.replaceTop(Route.Board(next, pack)) else nav.pop() },
            )
        }
        Toast(toast)
    }
}

/** The twelve keys, in two rows of six. */
@Composable
private fun LetterKeys(engine: GameEngine, onKey: (BankKey) -> Unit) {
    val half = (engine.bank.size + 1) / 2
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        for (row in listOf(engine.bank.take(half), engine.bank.drop(half))) {
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                for (key in row) {
                    val state = when {
                        key.removed -> KeyState.Removed
                        key.used -> KeyState.Used
                        else -> KeyState.Normal
                    }
                    LetterKey(key.letter, if (engine.currentSolved && state == KeyState.Normal) KeyState.Used else state, onClick = { onKey(key) })
                }
            }
        }
    }
}

// ---- what the board shows, worked out from the engine ----

private fun nextLevel(pack: Pack, level: Level): Level? = pack.levels.getOrNull(pack.levels.indexOf(level) + 1)

/** Earned letters, plus the letters being typed for the open word. */
private fun boardLetters(engine: GameEngine): Map<CellPos, String> {
    val letters = engine.filled.toMutableMap()
    val e: Entry = engine.current ?: return letters
    e.cells.forEachIndexed { i, cell ->
        val typed = engine.typed.getOrNull(i)
        if (engine.filled[cell] == null && typed != null) letters[cell] = typed
    }
    return letters
}

private fun cellStates(engine: GameEngine): Map<CellPos, CellState> {
    val active = engine.current?.cells?.toSet().orEmpty()
    return engine.allCells.associateWith { c ->
        when {
            c in engine.revealed -> CellState.Hint
            engine.filled[c] != null -> CellState.Solved
            c in active -> CellState.Active
            else -> CellState.Empty
        }
    }
}

private fun slotStates(engine: GameEngine): List<SlotState> = engine.typed.indices.map { i ->
    when {
        engine.currentSolved -> SlotState.Solved
        engine.isRevealed(i) -> SlotState.Revealed
        engine.isLocked(i) -> SlotState.Solved
        engine.lastWrong -> SlotState.Wrong
        engine.typed[i] == null -> SlotState.Empty
        else -> SlotState.Typed
    }
}

/** The next empty slot of the open word, outlined on the board. */
private fun cursorCell(engine: GameEngine): CellPos? {
    val e = engine.current ?: return null
    val i = engine.typed.indexOfFirst { it == null }
    return if (i >= 0) e.cells[i] else null
}

/** Biggest square cell that fits the space, between 24 and 50 dp. */
private fun cellSize(width: Dp, height: Dp, level: Level): Dp {
    val w = (width - Space.cellGap * (level.width - 1)) / level.width
    val h = (height - Space.cellGap * (level.height - 1)) / level.height
    return maxOf(24.dp, minOf(Space.cellMax + 6.dp, w, h))
}
