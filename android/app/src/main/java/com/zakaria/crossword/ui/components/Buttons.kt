package com.zakaria.crossword.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CleaningServices
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.TextSize

enum class ButtonStyle { Primary, Gold, Light }

/** The big rounded 3D button used for every main action. */
@Composable
fun GameButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    style: ButtonStyle = ButtonStyle.Primary,
    height: Dp = 56.dp,
    enabled: Boolean = true,
) {
    val (face, edge, text) = when (style) {
        ButtonStyle.Primary -> Triple(listOf(Palette.buttonLight, Palette.buttonShade), Palette.buttonEdge, Palette.onButton)
        ButtonStyle.Gold -> Triple(listOf(Palette.goldLight, Palette.goldShade), Palette.goldEdge, Palette.onGold)
        ButtonStyle.Light -> Triple(listOf(Palette.panel, Palette.tileShade), Palette.tileEdge, Palette.panelText)
    }
    Tile3D(
        face = face, edge = edge, radius = height / 2, depth = 5.dp,
        modifier = modifier
            .fillMaxWidth()
            .height(height + 5.dp)
            .alpha(if (enabled) 1f else 0.6f)
            .pressable(enabled, onClick),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(Space.sm), verticalAlignment = Alignment.CenterVertically) {
            if (icon != null) GameIcon(icon, text, size = height * 0.4f)
            ArabicText(title, size = (height.value * 0.36f).sp, color = text, maxLines = 1)
        }
    }
}

/** A hint button: icon, title and its price in coins. */
@Composable
fun HintButton(
    title: String,
    icon: ImageVector,
    iconColor: Color,
    cost: Int,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Tile3D(
        face = listOf(Palette.panel, Palette.tileShade), edge = Palette.tileEdge, radius = 20.dp,
        modifier = modifier
            .height(44.dp + Space.edge)
            .alpha(if (enabled) 1f else 0.45f)
            .pressable(enabled, onClick),
    ) {
        Row(
            Modifier.padding(horizontal = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            GameIcon(icon, iconColor)
            ArabicText(title, size = 15.sp, color = Palette.panelText, maxLines = 1)
            CoinChip(cost)
        }
    }
}

/** The crossword's two hints. */
@Composable
fun RevealHintButton(cost: Int, enabled: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier, title: String = "كشف حرف") =
    HintButton(title, Icons.Filled.Visibility, Palette.turquoise, cost, enabled, onClick, modifier)

@Composable
fun RemoveHintButton(cost: Int, enabled: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) =
    HintButton("حذف حرف", Icons.Filled.CleaningServices, Palette.button, cost, enabled, onClick, modifier)

/** Round glass button for the top bars (back, sound). */
@Composable
fun RoundIconButton(icon: ImageVector, label: String, onClick: () -> Unit) {
    Box(
        Modifier
            .size(44.dp)
            .background(Palette.coinPill.copy(alpha = 0.55f), CircleShape)
            .border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape)
            .semantics { contentDescription = label }
            .pressable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        GameIcon(icon, Color.White, size = 22.dp)
    }
}

/** Top bar over a scene: back button, title in the middle, actions at the end. */
@Composable
fun SceneTopBar(title: String, onBack: (() -> Unit)?, actions: @Composable () -> Unit = {}) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(Space.topBar)
            .padding(horizontal = Space.lg),
    ) {
        ArabicText(
            title, size = TextSize.title, color = Color.White, maxLines = 1,
            modifier = Modifier.align(Alignment.Center),
        )
        if (onBack != null) {
            Box(Modifier.align(Alignment.CenterStart)) {
                // auto-mirrored: points right in Arabic, the way "back" goes
                RoundIconButton(Icons.AutoMirrored.Filled.ArrowBack, "رجوع", onBack)
            }
        }
        Box(Modifier.align(Alignment.CenterEnd)) { actions() }
    }
}
