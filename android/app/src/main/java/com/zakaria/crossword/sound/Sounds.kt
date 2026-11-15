package com.zakaria.crossword.sound

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/** The game's sounds (shared .wav files with the iOS app). */
enum class Sound { Tap, Key, Undo, Wrong, Correct, Complete, Star, Hint, Erase, Coin, Open }

/**
 * Plays the game's sounds with a matching vibration.
 *
 * Like the iOS app: sounds mix with the player's music (SoundPool never takes audio focus)
 * and stay quiet when the phone is on silent or vibrate.
 */
object Sounds {
    /** The player's setting (top-bar speaker button). */
    var enabled = true

    private var pool: SoundPool? = null
    private val ids = mutableMapOf<Sound, Int>()
    private var audio: AudioManager? = null
    private var vibrator: Vibrator? = null

    fun init(context: Context) {
        if (pool != null) return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val p = SoundPool.Builder().setMaxStreams(6).setAudioAttributes(attributes).build()
        for (s in Sound.entries) {
            context.assets.openFd(s.name.lowercase() + ".wav").use { ids[s] = p.load(it, 1) }
        }
        pool = p
        audio = context.getSystemService(AudioManager::class.java)
        vibrator = if (Build.VERSION.SDK_INT >= 31) {
            context.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION") context.getSystemService(Vibrator::class.java)
        }
    }

    fun play(s: Sound) {
        vibrate(s)
        val silent = audio?.ringerMode != AudioManager.RINGER_MODE_NORMAL
        if (!enabled || silent) return
        ids[s]?.let { pool?.play(it, 1f, 1f, 1, 0, 1f) }
    }

    /** A light tick for keys, a double buzz for a wrong answer, a firm click for success. */
    private fun vibrate(s: Sound) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        val effect = if (Build.VERSION.SDK_INT >= 29) {
            when (s) {
                Sound.Key, Sound.Tap, Sound.Undo, Sound.Open -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
                Sound.Wrong -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_DOUBLE_CLICK)
                Sound.Correct, Sound.Complete -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK)
                Sound.Hint, Sound.Erase, Sound.Coin, Sound.Star -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
            }
        } else {
            VibrationEffect.createOneShot(if (s == Sound.Wrong) 40 else 12, VibrationEffect.DEFAULT_AMPLITUDE)
        }
        v.vibrate(effect)
    }
}
