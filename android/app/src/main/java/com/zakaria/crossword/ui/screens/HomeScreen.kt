package com.zakaria.crossword.ui.screens

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Gesture
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.LocalApp
import com.zakaria.crossword.model.GameMode
import com.zakaria.crossword.ui.components.ButtonStyle
import com.zakaria.crossword.ui.components.GameButton
import com.zakaria.crossword.ui.components.Pill
import com.zakaria.crossword.ui.components.SceneBackground
import com.zakaria.crossword.ui.components.SceneMood
import com.zakaria.crossword.ui.components.TopBarActions
import com.zakaria.crossword.ui.iq.IQButton
import com.zakaria.crossword.ui.navigation.Navigator
import com.zakaria.crossword.ui.navigation.Route
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.TextSize
import com.zakaria.crossword.ui.theme.arNum
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** S01 — scene, logo emblem, "continue" button and the two ways to play. */
@Composable
fun HomeScreen(nav: Navigator) {
    val app = LocalApp.current
    val store = app.store
    val next = store.nextLevel(app.packs)

    Box(Modifier.fillMaxSize()) {
        SceneBackground(next?.let { SceneMood.forPack(it.second.order) } ?: SceneMood.Night, duneHeight = 0.34f)

        Column(
            Modifier
                .fillMaxSize()
                .safeDrawingPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.lg),
        ) {
            Row(Modifier.fillMaxWidth().padding(horizontal = Space.lg), horizontalArrangement = Arrangement.End) {
                TopBarActions()
            }
            Spacer(Modifier.weight(1f))
            Emblem()
            IQButton()
            Spacer(Modifier.weight(1f))

            Column(
                Modifier.padding(horizontal = Space.xl).padding(bottom = Space.xl),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Space.md),
            ) {
                if (next != null) {
                    val (level, pack) = next
                    GameButton(
                        title = if (store.file.levels.isEmpty()) "ابدأ اللعب" else "تابع اللعب",
                        icon = Icons.Filled.PlayArrow, style = ButtonStyle.Gold, height = 64.dp,
                        onClick = { nav.push(Route.Board(level, pack)) },
                    )
                    Pill("${pack.titleAr} · لغز ${arNum(level.number)}")
                } else if (app.packs.isNotEmpty()) {
                    ArabicText("أنهيت كل الألغاز! انتظر مجموعات جديدة قريبًا", TextSize.body, Color.White, align = TextAlign.Center)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(Space.md)) {
                    GameButton(
                        title = GameMode.WordSearch.title, icon = Icons.Filled.Gesture, height = 52.dp,
                        modifier = Modifier.weight(1f), enabled = app.wsPacks.isNotEmpty(),
                        onClick = {
                            // straight into the next word search, or the packs when all are done
                            val ws = store.nextLevel(app.wsPacks)
                            nav.push(if (ws != null) Route.Board(ws.first, ws.second) else Route.Packs(GameMode.WordSearch))
                        },
                    )
                    GameButton(
                        title = "المجموعات", icon = Icons.Filled.GridView, style = ButtonStyle.Light, height = 52.dp,
                        modifier = Modifier.weight(1f), enabled = app.packs.isNotEmpty(),
                        onClick = { nav.push(Route.Packs(GameMode.Crossword)) },
                    )
                }
            }
        }
    }
}

/** The logo: "كلمات" on a gold eight-point star with a 3D rim, plus the tagline. */
@Composable
private fun Emblem() {
    val appear = remember { Animatable(0.8f) }
    LaunchedEffect(Unit) { appear.animateTo(1f, spring(dampingRatio = 0.7f, stiffness = 120f)) }
    val spin by rememberInfiniteTransition(label = "emblem")
        .animateFloat(0f, 45f, infiniteRepeatable(tween(8000), RepeatMode.Reverse), label = "spin")

    Column(
        Modifier
            .graphicsLayer {
                scaleX = appear.value; scaleY = appear.value
                alpha = ((appear.value - 0.8f) / 0.2f).coerceIn(0f, 1f)
            }
            .clearAndSetSemantics { contentDescription = "كلمات — كلمات متقاطعة بنكهة خليجية" },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.md),
    ) {
        Box(Modifier.size(236.dp), contentAlignment = Alignment.Center) {
            Canvas(Modifier.size(236.dp)) {
                translate(top = 6.dp.toPx()) { drawPath(eightPointStar(size.minDimension / 2), Palette.goldEdge) }
                drawPath(eightPointStar(size.minDimension / 2), Brush.verticalGradient(listOf(Color(0xFFFFE08A), Palette.goldShade)))
            }
            Canvas(Modifier.size(206.dp).rotate(spin)) {
                drawPath(eightPointStar(size.minDimension / 2), Color(0xFFFFF1C2), style = Stroke(2.dp.toPx()))
            }
            Box(
                Modifier
                    .size(150.dp)
                    .shadow(6.dp, CircleShape)
                    .background(Palette.button, CircleShape)
                    .border(4.dp, Palette.buttonEdge, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                ArabicText("كلمات", 46.sp, Color.White, modifier = Modifier.offset(y = (-4).dp))
            }
        }
        ArabicText(
            "كلمات متقاطعة بنكهة خليجية", 18.sp, Color.White,
            modifier = Modifier
                .background(Palette.coinPill.copy(alpha = 0.55f), CircleShape)
                .padding(horizontal = Space.lg, vertical = 6.dp),
        )
    }
}

/** Eight-point star (two squares rotated 45°) as one outline, centred in the canvas. */
private fun DrawScope.eightPointStar(outer: Float): Path {
    val inner = outer * 0.80f
    return Path().apply {
        for (i in 0 until 16) {
            val a = i * PI.toFloat() / 8 - PI.toFloat() / 2
            val r = if (i % 2 == 0) outer else inner
            val p = Offset(center.x + cos(a) * r, center.y + sin(a) * r)
            if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y)
        }
        close()
    }
}
