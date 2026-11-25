package com.zakaria.crossword.ads

import android.app.Activity
import android.os.SystemClock
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import com.zakaria.crossword.BuildConfig
import java.util.concurrent.atomic.AtomicBoolean

/**
 * The only file that knows the ad SDK (swapping networks later touches this file only).
 *
 * Order, per Google's rules: consent form (UMP) → if ads may be requested, start the SDK → load ads.
 *
 * Ad policy (same as iOS):
 * - rewarded: only when the player taps "watch for coins"
 * - interstitial: only between levels, at least 3 levels and 180 s apart, never before level 4
 */
object Ads {
    const val REWARD_COINS = 50
    private const val INTERSTITIAL_EVERY_LEVELS = 3
    private const val INTERSTITIAL_MIN_MS = 180_000L
    private const val FIRST_INTERSTITIAL_AFTER_LEVEL = 3
    private const val TAG = "Ads"

    // Compose state: the coin cards and the solve clock read these.
    var canRequestAds by mutableStateOf(false); private set
    var rewardedReady by mutableStateOf(false); private set
    var privacyOptionsRequired by mutableStateOf(false); private set
    /** True while a full-screen ad covers the game (the IQ clock pauses). */
    var showingFullScreen by mutableStateOf(false); private set

    private var rewarded: RewardedAd? = null
    private var interstitial: InterstitialAd? = null
    private var levelsSinceInterstitial = 0
    private var lastInterstitialAt = -INTERSTITIAL_MIN_MS
    private val sdkStarted = AtomicBoolean(false)
    private var consent: ConsentInformation? = null

    // ---- start ----

    /** Call once from the activity. Shows Google's consent form when the law requires it. */
    fun start(activity: Activity) {
        if (consent != null) return
        val info = UserMessagingPlatform.getConsentInformation(activity)
        consent = info
        info.requestConsentInfoUpdate(
            activity, ConsentRequestParameters.Builder().build(),
            {
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { error ->
                    if (error != null) Log.w(TAG, "consent form: ${error.message}")
                    privacyOptionsRequired =
                        info.privacyOptionsRequirementStatus == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
                    startSdkIfAllowed(activity)
                }
            },
            { error -> Log.w(TAG, "consent info update failed: ${error.message}") },
        )
        // Consent given on an earlier launch may already allow ads.
        startSdkIfAllowed(activity)
    }

    private fun startSdkIfAllowed(activity: Activity) {
        if (consent?.canRequestAds() != true || sdkStarted.getAndSet(true)) return
        canRequestAds = true
        MobileAds.initialize(activity.applicationContext) {
            activity.runOnUiThread {
                loadRewarded(activity)
                loadInterstitial(activity)
            }
        }
    }

    /** Lets the player change their consent choices (required in some regions). */
    fun showPrivacyOptions(activity: Activity) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity) { error ->
            if (error != null) Log.w(TAG, "privacy options: ${error.message}")
        }
    }

    // ---- rewarded ----

    private fun loadRewarded(activity: Activity) {
        if (!canRequestAds) return
        rewardedReady = false
        RewardedAd.load(activity, BuildConfig.AD_UNIT_REWARDED, AdRequest.Builder().build(), object : RewardedAdLoadCallback() {
            override fun onAdLoaded(ad: RewardedAd) {
                rewarded = ad
                rewardedReady = true
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                Log.w(TAG, "rewarded load failed: ${error.message}")
                rewarded = null
            }
        })
    }

    /** Shows a rewarded ad; [earned] runs only if the player watched it through. */
    fun showRewarded(activity: Activity, earned: () -> Unit) {
        val ad = rewarded ?: return
        rewarded = null
        rewardedReady = false
        ad.fullScreenContentCallback = callback { loadRewarded(activity) }
        ad.show(activity) { earned() }
    }

    // ---- interstitial ----

    private fun loadInterstitial(activity: Activity) {
        if (!canRequestAds) return
        InterstitialAd.load(activity, BuildConfig.AD_UNIT_INTERSTITIAL, AdRequest.Builder().build(), object : InterstitialAdLoadCallback() {
            override fun onAdLoaded(ad: InterstitialAd) {
                interstitial = ad
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                interstitial = null
            }
        })
    }

    /**
     * Call when the player leaves a finished level. Shows an interstitial only if the
     * frequency rules allow it; otherwise does nothing.
     */
    fun levelFinished(activity: Activity, levelNumber: Int) {
        levelsSinceInterstitial++
        val now = SystemClock.elapsedRealtime()
        val ad = interstitial ?: return
        if (levelNumber <= FIRST_INTERSTITIAL_AFTER_LEVEL) return
        if (levelsSinceInterstitial < INTERSTITIAL_EVERY_LEVELS) return
        if (now - lastInterstitialAt < INTERSTITIAL_MIN_MS) return

        levelsSinceInterstitial = 0
        lastInterstitialAt = now
        interstitial = null
        ad.fullScreenContentCallback = callback { loadInterstitial(activity) }
        ad.show(activity)
    }

    /** Tracks when an ad covers the screen, then loads the next one. */
    private fun callback(reload: () -> Unit) = object : FullScreenContentCallback() {
        override fun onAdShowedFullScreenContent() {
            showingFullScreen = true
        }

        override fun onAdDismissedFullScreenContent() {
            showingFullScreen = false
            reload()
        }

        override fun onAdFailedToShowFullScreenContent(error: AdError) {
            showingFullScreen = false
            reload()
        }
    }
}
