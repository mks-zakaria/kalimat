package com.zakaria.crossword.ui.theme

import android.content.res.AssetManager
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp

/**
 * Noto Naskh Arabic (SIL OFL 1.1), a variable font shared with the iOS app.
 * Set once at start-up by [Fonts.load].
 */
object Fonts {
    var arabic: FontFamily = FontFamily.Default
        private set

    fun load(assets: AssetManager) {
        fun weight(w: FontWeight) = Font(
            "NotoNaskhArabic.ttf", assets, weight = w,
            variationSettings = FontVariation.Settings(FontVariation.weight(w.weight)),
        )
        arabic = FontFamily(weight(FontWeight.Normal), weight(FontWeight.SemiBold), weight(FontWeight.Bold))
    }
}

/** Arabic text in the game font. Sizes are fixed (the app turns off system font scaling, like iOS). */
@Composable
fun ArabicText(
    text: String,
    size: TextUnit,
    color: Color,
    modifier: Modifier = Modifier,
    weight: FontWeight = FontWeight.Bold,
    align: TextAlign = TextAlign.Unspecified,
    maxLines: Int = Int.MAX_VALUE,
    strike: Boolean = false,
) {
    BasicText(
        text = text,
        modifier = modifier,
        style = TextStyle(
            fontFamily = Fonts.arabic, fontSize = size, fontWeight = weight, color = color, textAlign = align,
            textDecoration = if (strike) TextDecoration.LineThrough else null,
        ),
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
    )
}

/** Numbers: heavy rounded system font, like the iOS `.rounded` design. */
@Composable
fun NumberText(text: String, size: TextUnit, color: Color, modifier: Modifier = Modifier) {
    BasicText(
        text = text,
        modifier = modifier,
        style = TextStyle(fontSize = size, fontWeight = FontWeight.Black, color = color),
        maxLines = 1,
    )
}

/** Font sizes used across the app. */
object TextSize {
    val caption = 13.sp
    val body = 17.sp
    val clue = 21.sp
    val title = 22.sp
    val number = 17.sp
}

/** Numbers shown as Arabic-Indic digits (٠١٢…), as Gulf players read them. */
fun arNum(n: Int): String = n.toString().map { if (it in '0'..'9') '٠' + (it - '0') else it }.joinToString("")
