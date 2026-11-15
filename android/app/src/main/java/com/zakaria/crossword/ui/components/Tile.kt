package com.zakaria.crossword.ui.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.zakaria.crossword.ui.theme.Radius
import com.zakaria.crossword.ui.theme.Space

/**
 * A raised tile: a gradient face with a darker edge drawn below it.
 * The size given by [modifier] includes the edge (face height = height − [depth]).
 */
@Composable
fun Tile3D(
    face: List<Color>,
    edge: Color,
    modifier: Modifier = Modifier,
    radius: Dp = Radius.key,
    depth: Dp = Space.edge,
    content: @Composable BoxScope.() -> Unit = {},
) {
    val shape = RoundedCornerShape(radius)
    Box(
        modifier
            .padding(bottom = depth)
            .drawBehind {
                // the edge: same shape, pushed down by `depth`
                drawRoundRect(edge, topLeft = Offset(0f, depth.toPx()), size = size, cornerRadius = CornerRadius(radius.toPx()))
            }
            .background(Brush.verticalGradient(face), shape)
            .border(1.dp, Color.White.copy(alpha = 0.55f), shape),
        contentAlignment = Alignment.Center,
        content = content,
    )
}

/** Makes anything a button that shrinks a little while pressed (no ripple, like the iOS game). */
@Composable
fun Modifier.pressable(enabled: Boolean = true, onClick: () -> Unit): Modifier {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed && enabled) 0.95f else 1f,
        animationSpec = spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessHigh),
        label = "press",
    )
    return this
        .graphicsLayer { scaleX = scale; scaleY = scale }
        .clickable(interactionSource = source, indication = null, enabled = enabled, role = Role.Button, onClick = onClick)
}
