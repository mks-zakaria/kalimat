package com.zakaria.crossword.ui.coins

import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SmartDisplay
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zakaria.crossword.AppLinks
import com.zakaria.crossword.LocalApp
import com.zakaria.crossword.ads.Ads
import com.zakaria.crossword.data.ProgressStore
import com.zakaria.crossword.sound.Sound
import com.zakaria.crossword.sound.Sounds
import com.zakaria.crossword.ui.components.ButtonStyle
import com.zakaria.crossword.ui.components.CoinChip
import com.zakaria.crossword.ui.components.CoinIcon
import com.zakaria.crossword.ui.components.GameButton
import com.zakaria.crossword.ui.components.GameDialog
import com.zakaria.crossword.ui.components.GameIcon
import com.zakaria.crossword.ui.components.Panel
import com.zakaria.crossword.ui.components.pressable
import com.zakaria.crossword.ui.theme.ArabicText
import com.zakaria.crossword.ui.theme.NumberText
import com.zakaria.crossword.ui.theme.Palette
import com.zakaria.crossword.ui.theme.Space
import com.zakaria.crossword.ui.theme.TextSize
import com.zakaria.crossword.ui.theme.arNum

/** S07 — the coin balance, how to earn coins, and the legal links. Opened from the coin counter. */
@Composable
fun CoinsCard(onClose: () -> Unit) {
    val store = LocalApp.current.store
    val close = { Sounds.play(Sound.Tap); onClose() }

    GameDialog(onDismiss = close) {
        CoinIcon(64.dp)
        NumberText(arNum(store.coins), 44.sp, Palette.panelText)
        ArabicText("رصيدك من العملات", TextSize.body, Palette.panelMuted, weight = FontWeight.Normal)

        Panel(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(Space.lg), verticalArrangement = Arrangement.spacedBy(Space.md)) {
                ArabicText("كيف تربح العملات؟", TextSize.title, Palette.panelText)
                EarnRow(Icons.Filled.Verified, "أنهِ لغزًا جديدًا", 5)
                EarnRow(Icons.Filled.Star, "أنهِه بثلاث نجوم بدون مساعدة", 10)
                Row(Modifier.fillMaxWidth().height(1.dp).background(Palette.tileEdge.copy(alpha = 0.3f))) {}
                ArabicText(
                    "استخدم العملات لكشف حرف (${arNum(ProgressStore.REVEAL_COST)}) أو حذف حرف خاطئ (${arNum(ProgressStore.REMOVE_COST)}).",
                    TextSize.caption, Palette.panelMuted,
                )
            }
        }

        if (Ads.canRequestAds) {
            var justEarned by remember { mutableStateOf(false) }
            WatchAdButton(ButtonStyle.Primary, onEarned = { justEarned = true })
            if (justEarned) {
                ArabicText("أضفنا ${arNum(Ads.REWARD_COINS)} عملة إلى رصيدك", TextSize.caption, Palette.success)
            }
        }
        GameButton("حسنًا", onClick = close, style = ButtonStyle.Gold, height = 52.dp)
        if (Ads.privacyOptionsRequired) {
            val activity = LocalActivity.current
            Link("إعدادات الخصوصية والإعلانات") { activity?.let { Ads.showPrivacyOptions(it) } }
        }
        LegalLinks()
    }
}

@Composable
private fun EarnRow(icon: ImageVector, text: String, amount: Int) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Space.md), verticalAlignment = Alignment.CenterVertically) {
        GameIcon(icon, Palette.goldShade, size = 22.dp)
        ArabicText(text, TextSize.body, Palette.panelText, Modifier.weight(1f), weight = FontWeight.Normal)
        CoinChip(amount)
    }
}

/** Privacy policy · Terms · Support, opened in the browser. */
@Composable
private fun LegalLinks() {
    val uri = LocalUriHandler.current
    Row(horizontalArrangement = Arrangement.spacedBy(Space.md), verticalAlignment = Alignment.CenterVertically) {
        Link("سياسة الخصوصية") { uri.openUri(AppLinks.PRIVACY) }
        ArabicText("·", TextSize.caption, Palette.panelMuted)
        Link("الشروط العامة") { uri.openUri(AppLinks.TERMS) }
        ArabicText("·", TextSize.caption, Palette.panelMuted)
        Link("الدعم") { uri.openUri(AppLinks.SUPPORT) }
    }
}

@Composable
private fun Link(text: String, onClick: () -> Unit) {
    ArabicText(text, TextSize.caption, Palette.panelMuted, Modifier.pressable(onClick = onClick).padding(vertical = 6.dp))
}

/** Shown when a hint costs more coins than the player has. */
@Composable
fun NoCoinsCard(onClose: () -> Unit) {
    val close = { Sounds.play(Sound.Tap); onClose() }
    GameDialog(onDismiss = close) {
        CoinIcon(64.dp)
        ArabicText("رصيدك من العملات لا يكفي", TextSize.title, Palette.panelText)
        ArabicText(
            "أنهِ الألغاز لتربح عملات: ٥ لكل لغز و١٠ إذا حصلت على ٣ نجوم.",
            TextSize.body, Palette.panelMuted, weight = FontWeight.Normal, align = TextAlign.Center,
        )
        if (Ads.canRequestAds) WatchAdButton(ButtonStyle.Gold, beforeShow = onClose)
        GameButton("حسنًا", onClick = close, style = ButtonStyle.Light, height = 50.dp)
    }
}

/**
 * "Watch an ad and win 50" — shows a rewarded ad and adds the coins only if it was watched through.
 * [beforeShow] closes the card first when the ad should not appear on top of it.
 */
@Composable
private fun WatchAdButton(style: ButtonStyle, beforeShow: () -> Unit = {}, onEarned: () -> Unit = {}) {
    val store = LocalApp.current.store
    val activity = LocalActivity.current
    val ready = Ads.rewardedReady
    GameButton(
        title = if (ready) "شاهد إعلانًا واربح ${arNum(Ads.REWARD_COINS)}" else "جارٍ تجهيز الإعلان…",
        icon = Icons.Filled.SmartDisplay, style = style, height = 52.dp, enabled = ready,
        onClick = {
            if (activity == null) return@GameButton
            beforeShow()
            Ads.showRewarded(activity) {
                store.earn(Ads.REWARD_COINS)
                Sounds.play(Sound.Coin)
                onEarned()
            }
        },
    )
}
