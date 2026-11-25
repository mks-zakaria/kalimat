package com.zakaria.crossword.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Space
import kotlinx.coroutines.delay

/** Short message that slides in from the top and hides itself after 2 seconds. Set its value to show it. */
@Composable
fun rememberToast(): MutableState<String?> = remember { mutableStateOf(null) }

@Composable
fun Toast(message: MutableState<String?>) {
    var last by remember { mutableStateOf("") }               // keeps the text while it slides out
    message.value?.let { last = it }
    LaunchedEffect(message.value) {
        if (message.value != null) {
            delay(2000)
            message.value = null
        }
    }
    Box(Modifier.fillMaxWidth().safeDrawingPadding().padding(top = 64.dp), contentAlignment = Alignment.TopCenter) {
        AnimatedVisibility(
            visible = message.value != null,
            enter = slideInVertically { -it } + fadeIn(),
            exit = slideOutVertically { -it } + fadeOut(),
        ) {
            ArabicText(
                last, 16.sp, Color.White,
                modifier = Modifier
                    .background(Palette.coinPill.copy(alpha = 0.9f), CircleShape)
                    .border(1.5.dp, Palette.gold, CircleShape)
                    .padding(horizontal = Space.lg, vertical = Space.sm),
            )
        }
    }
}
