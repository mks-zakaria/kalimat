package com.zakaria.crossword.ui.iq

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Autorenew
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.LocalApp
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds
import com.zakaria.crossword.ui.components.ButtonStyle
import com.zakaria.crossword.ui.components.GameButton
import com.zakaria.crossword.ui.components.GameDialog
import com.zakaria.crossword.ui.components.GameIcon
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.NumberText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Radius
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.TextSize
import com.zakaria.crossword.ui.theme.arNum

/** What the IQ score is, how it is calculated, and the player's numbers. */
@Composable
fun IQCard(onClose: () -> Unit) {
    val store = LocalApp.current.store
    val close = { Sounds.play(Sound.Tap); onClose() }

    GameDialog(onDismiss = close, borderColor = Palette.turquoise) {
        Box(Modifier.size(84.dp).background(Palette.turquoise.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) {
            GameIcon(Icons.Filled.Psychology, Palette.turquoise, size = 46.dp)
        }
        ArabicText("ما هو معدّل الذكاء؟", TextSize.title, Palette.panelText)

        Row(horizontalArrangement = Arrangement.spacedBy(Space.sm)) {
            Stat(store.iq?.let(::arNum) ?: "—", "معدّلك", Modifier.weight(1f))
            Stat(store.bestLevelIQ?.let(::arNum) ?: "—", "أفضل لغز", Modifier.weight(1f))
            Stat(store.lastLevelIQ?.let(::arNum) ?: "—", "آخر لغز", Modifier.weight(1f))
        }

        Column(verticalArrangement = Arrangement.spacedBy(Space.sm)) {
            Line(Icons.Filled.Timer, "نقيس وقت حلّك الفعلي لكل لغز جديد، دون وقت الإعلانات أو خروجك من اللعبة.")
            Line(Icons.Filled.Speed, "نقارنه بالوقت المتوقع حسب عدد الكلمات وطولها وصعوبتها: في الوقت = ١٠٠، أسرع بمرتين = ١٢٠، أبطأ بمرتين = ٨٠.")
            Line(Icons.Outlined.Lightbulb, "كل مساعدة تنقص ٥ نقاط من نتيجة اللغز.")
            Line(Icons.Filled.Autorenew, "بعد كل لغز يتحدّث معدّلك بين نتيجتك فيه ومعدّلك السابق، فيرتفع إذا كنت أسرع ويهبط إذا كنت أبطأ. إعادة اللعب لا تُحتسب.")
        }

        ArabicText(
            if (store.iq == null) "أنهِ لغزك الأول لتعرف معدّلك." else "مبني على ${puzzles(store.file.iqLevels)}.",
            TextSize.caption, Palette.panelMuted,
        )
        ArabicText(
            "تقدير للمتعة مبني على سرعتك في الحل، وليس اختبار ذكاء علميًا.",
            TextSize.caption, Palette.panelMuted, align = TextAlign.Center,
        )
        GameButton("حسنًا", onClick = close, style = ButtonStyle.Gold, height = 50.dp)
    }
}

@Composable
private fun Stat(value: String, label: String, modifier: Modifier) {
    val shape = RoundedCornerShape(Radius.key)
    Column(
        modifier
            .background(Palette.tile, shape)
            .border(1.dp, Palette.tileEdge.copy(alpha = 0.35f), shape)
            .padding(vertical = Space.sm),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        NumberText(value, 26.sp, Palette.panelText)
        ArabicText(label, TextSize.caption, Palette.panelMuted)
    }
}

@Composable
private fun Line(icon: ImageVector, text: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Space.md)) {
        GameIcon(icon, Palette.goldShade, modifier = Modifier.padding(top = 2.dp))
        ArabicText(text, 14.sp, Palette.panelText, weight = FontWeight.Normal)
    }
}

/** "لغز واحد / لغزين / ٣ ألغاز / ١١ لغزًا" */
private fun puzzles(n: Int): String = when {
    n == 1 -> "لغز واحد"
    n == 2 -> "لغزين"
    n % 100 in 3..10 -> "${arNum(n)} ألغاز"
    else -> "${arNum(n)} لغزًا"
}
